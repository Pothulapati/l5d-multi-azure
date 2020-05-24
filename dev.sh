!/bin/bash

set -eu
set -x

# Links and allows a local l5d environment, which service mirroing enabled from east and west

export DEV="${DEV:-microk8s}"

# Allow and Link, dev in east and west
for remote in east west ; do 
	
	# Allow
	linkerd --context="$remote" cluster allow dev | kubectl --context="$remote" apply -f -

        # Link	
	linkerd --context="$remote" cluster link dev --cluster-name="$remote" | kubectl --context="$DEV" apply -f -  

done


# Now run multi-cluster health-checks in $DEV
linkerd --context="$DEV" check --multicluster

