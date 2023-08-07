# asdb-6.0-storage-change-record-checker
Simple bash script to deploy the Aerospike Kubernetes Operator via OLM to a kubenetes cluster

## Usage
```bash
Usage: ./setup_olm.sh -n CLUSTER_NAME -v K8S_VERSION [-o OLM_VERSION] [ -R ]

-n) EKS cluster name to attach to
-v) Kubernetes version to use when attaching via gaiakube
-o) OLM version to install: Default v0.21.2
-R) Run cleanup to remove OLM, operators, and aerospike namespace
```

```bash
./setup_olm.sh -n colton -v 1.27
```



