# Linkerd2 Multi-Cluster Setup on AKS

Inspired from [l2-k3d-multi](https://github.com/olix0r/l2-k3d-multi), but on AKS and with a different demo.

Here, we will setup three clusters i.e `dev`, `east` and `west`. `east` and `west` are in Az but dev is present locally
configured through `$DEV`.

`$LOCATION` and `$GROUP` can be used to configure Az Datacenter location and resource group of the azure clusters.

Running `./setup.sh` creates two az clusters, Installs Linkerd and also sets up service mirroring between them.
It also Installs linkerd in the `$DEV` cluster. The script will use a common trust root for all the three linkerd installations
as its necessarry for multi-cluster

Running `./dev.sh` sets up service-mirroring in `$DEV` for both `east` and `west`.
