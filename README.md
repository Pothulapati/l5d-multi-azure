# Linkerd2 Multi-Cluster Setup on AKS

Inspired from [l2-k3d-multi](https://github.com/olix0r/l2-k3d-multi), but on AKS.

## Prerequisites

- [step]() and [az]() tools installed.
- [Linkerd CLI latest edge]()
- 2 clusters already provisioned in Azure , and their names are set to globals `$CLUSTER1` and `$CLUSTER2`.
- $LOCATION` and `$GROUP` can be used to configure Az Datacenter location and resource group of the azure clusters.

## Installation

Running `./setup.sh`,  Installs Linkerd and also sets up service mirroring between them in `$CLUSTER1` & `$CLUSTER2`
It also Installs linkerd in the `$DEV` cluster. The script will use a common trust root for all the three linkerd installations
as its necessarry for multi-cluster.

Running `./dev.sh` sets up service-mirroring in `$DEV` for both `$CLUSTER1` and `$CLUSTER2`.

The above scripts also install [emojivoto sample application]() into your clusters.

Now, Let's expose `web-svc` in `emojivoto`

- In `$CLUSTER1`

```bash
kubectl --context $CLUSTER1 -n emojivoto get svc emoji-svc -oyaml | linkerd cluster export-service -  | kubectl --context $CLUSTER1 apply -f -
```

- In `$CLUSTER2`

```bash
kubectl --context $CLUSTER2 -n emojivoto get svc emoji-svc -oyaml | linkerd cluster export-service -  | kubectl --context $CLUSTER2 apply -f -
```

Now, Let's make the `vote-bot` application in `$DEV` split traffic between the web-svc instances in `$CLUSTER1` and `$CLUSTER2`
Make sure to replaces the back-end service names with `$CLUSTER1` and `$CLUSTER2` below

```bash
cat <<EOF | kubectl --context=$DEV apply -f -
apiVersion: split.smi-spec.io/v1alpha1
kind: TrafficSplit
metadata:
  name: web
  namespace: emojivoto
spec:
  service: web-svc
  backends:
  - service: web-svc-$CLUSTER1
    weight: 500m
  - service: web-svc-$CLUSTER2
    weight: 500m
EOF
```

After running this, you can see that the local $DEV cluster talking to the gateway instances of the remote clusters by running
```bash
linkerd --context=$DEV cluster gateways
CLUSTER        NAMESPACE             NAME             ALIVE    NUM_SVC  LATENCY_P50  LATENCY_P95  LATENCY_P99
southeastasia  linkerd-multicluster  linkerd-gateway  True           1         63ms         96ms         99ms
westus         linkerd-multicluster  linkerd-gateway  True           1        250ms        295ms        299ms
```

You should also be able to see the stats of traffic-split resource by running

```bash
linkerd --context=$DEV -n emojivoto stat ts
NAME   APEX      LEAF                    WEIGHT   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99
web    web-svc   web-svc-southeastasia     500m    87.76%   0.8rps          75ms          98ms         100ms
web    web-svc   web-svc-westus            500m    87.50%   0.7rps         267ms         380ms         396ms
```

