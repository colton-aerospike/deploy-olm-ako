# deploy-olm-ako
Simple bash script to deploy the Aerospike Kubernetes Operator via OLM to a kubenetes cluster

## Installation
```bash
git clone https://github.com/colton-aerospike/deploy-olm-ako && cd deploy-olm-ako
```

## Usage
```bash
Usage: ./setup_olm.sh -f EKSCTL_YAML_FILE [-o OLM_VERSION, -E] [ -R ]

-f) EKSCTL configuration yaml file
-o) OLM version to install: (Default: v0.25.0)
-A) Install and Configure Amazon cluster-autoscaler (Default: false)
-E) Install OpenEBS Operator (Default: false)
-R) Run cleanup to remove OLM, operators, and aerospike namespace
```
## Basic Install
```bash
./setup_olm.sh -f /root/eks/basic.yaml
```

## Deploy OLM and OpenEBS, then configure Amazon cluster-autoscaler
```bash
./setup_olm.sh -f /root/eks/basic.yaml -E -A
```

## Remove OLM installation
```bash
./setup_olm.sh -f /root/eks/basic.yaml -R
``` 
