#!/bin/bash

set -eu
set -x

# Requires:
# - Two clusters east and west, because cluster creation fails in azure through az because
#   az aks is too fast, causing creation to fail before the required service profile creation is reflected :(
# - az : https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
# - smallstep/cli: https://github.com/smallstep/cli/releases
# - linkerd:edge-20.5.3: https://github.com/linkerd/linkerd2/releases/tag/edge-20.5.3

export DEV="${DEV:-microk8s}"
export LOCATION="${LOCATION:-southeastasia}"
export GROUP="${GROUP:-clusters}"

CA_DIR=$(mktemp --tmpdir="${TMPDIR:-/tmp}" -d az-ca.XXXXX)

# Generate the trust roots. These never touch the cluster. In the real world
# we'd squirrel these away in a vault.
step certificate create \
    "identity.linkerd.cluster.local" \
    "$CA_DIR/ca.crt" "$CA_DIR/ca.key" \
    --profile root-ca \
    --no-password  --insecure --force

# Create a "$GROUP" resource group
 az group create --name "$GROUP" --location "$LOCATION"

for cluster in east west ; do

    az aks get-credentials -n "$cluster" -g "$GROUP"

    # Check that the cluster is up and running.
    while ! linkerd --context="$cluster" check --pre ; do :; done

    # Create issuing credentials. These end up on the cluster (and can be
    # rotated from the root).
    crt="${CA_DIR}/${cluster}-issuer.crt"
    key="${CA_DIR}/${cluster}-issuer.key"
    step certificate create "identity.linkerd.cluster.local" \
        "$crt" "$key" \
        --ca="$CA_DIR/ca.crt" \
        --ca-key="$CA_DIR/ca.key" \
        --profile=intermediate-ca \
        --not-after 8760h --no-password --insecure

    # Install Linkerd into the cluster.
    linkerd --context="$cluster" install \
            --identity-trust-anchors-file="$CA_DIR/ca.crt" \
            --identity-issuer-certificate-file="${crt}" \
            --identity-issuer-key-file="${key}" |
        kubectl --context="$cluster" apply -f -

    # Wait some time and check that the cluster has started properly.
    sleep 30
    while ! linkerd --context="$cluster" check ; do :; done

    # Setup gateway and service mirror on both clusters
    linkerd --context="$cluster" cluster install | kubectl --context="$cluster" apply -f -

    # Install emojivoto on the cluster
     curl -sL https://run.linkerd.io/emojivoto.yml | linkerd --context "$cluster" inject - | kubectl --context "$cluster" apply -f -
	  

done


# Allow i.e install SA's that make possible remote to access this cluster
# Allow access of west in east
linkerd --context=east cluster allow --service-account-name west | kubectl --context=east apply -f -
# Allow access of east in west
linkerd --context=west cluster allow --service-account-name east | kubectl --context=west apply -f -

# Link i.e give the present cluster's secret to the other cluster, allowing it to mirror these services there
# Linking east to west
linkerd --context=east cluster link --service-account west --cluster-name east | kubectl --context west apply -f -
# Linking west to east
linkerd --context=west cluster link --service-account east --cluster-name west | kubectl --context east apply -f -

# As dev also need to use the intermediate CA let's install dev here only

# Pre Check
linkerd --context="$DEV" check --pre

# Create issuing credentials. These end up on the cluster (and can be
# rotated from the root).
crt="${CA_DIR}/${DEV}-issuer.crt"
key="${CA_DIR}/${DEV}-issuer.key"
step certificate create "identity.linkerd.cluster.local" \
    "$crt" "$key" \
    --ca="$CA_DIR/ca.crt" \
    --ca-key="$CA_DIR/ca.key" \
    --profile=intermediate-ca \
    --not-after 8760h --no-password --insecure

# Install Linkerd into the cluster.
linkerd --context="$DEV" install \
        --identity-trust-anchors-file="$CA_DIR/ca.crt" \
        --identity-issuer-certificate-file="${crt}" \
        --identity-issuer-key-file="${key}" |
        kubectl --context="$DEV" apply -f -

