!/bin/bash

set -eu
set -x

# Links and allows a local l5d environment, which service mirroing enabled from east and west

export CLUSTER1="${CLUSTER1:-southeastasia}"
export CLUSTER2="${CLUSTER2:-westus}"
export DEV="${DEV:-microk8s}"

# Check for Linkerd
linkerd --context="$DEV" check

# Install service-mirror in $DEV
linkerd --context="$DEV" mc install --gateway=false | kubectl --context="$DEV" apply -f -

# Allow and Link, dev in east and west
for remote in $CLUSTER1 $CLUSTER2 ; do 
	
	# Allow
	linkerd --context="$remote" mc allow --ignore-cluster --service-account-name dev | kubectl --context="$remote" apply -f -

        # Link	
	linkerd --context="$remote" mc link  --service-account dev --cluster-name="$remote" | kubectl --context="$DEV" apply -f -  

done


# Now run multi-cluster health-checks in $DEV
linkerd --context="$DEV" check --multicluster

curl -sL https://run.linkerd.io/emojivoto.yml | linkerd --context "$DEV" inject - | kubectl --context "$DEV" apply -f -
