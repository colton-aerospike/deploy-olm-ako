# deploy-olm-ako
Simple bash script to deploy the Aerospike Kubernetes Operator via OLM to a kubenetes cluster

## Usage
```bash
Usage: ./setup_olm.sh -n CLUSTER_NAME -v K8S_VERSION [-o OLM_VERSION, -E] [ -R ]

-n) EKS cluster name to attach to
-v) Kubernetes version to use when attaching via gaiakube
-o) OLM version to install: (Default: v0.25.0)
-A) Install and Configure Amazon cluster-autoscaler (Default: false)
-E) Install OpenEBS Operator (Default: false)
-R) Run cleanup to remove OLM, operators, and aerospike namespace
```
## Basic Install
```bash
./setup_olm.sh -n colton -v 1.27
```

## Deploy OLM and OpenEBS, then configure Amazon cluster-autoscaler
```bash
./setup_olm.sh -n colton -v 1.27 -E -A
```

## Remove OLM installation
```bash
./setup_olm.sh -n colton -v 1.27 -R
``` 


