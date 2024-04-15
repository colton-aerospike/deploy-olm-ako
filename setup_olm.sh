#!/bin/bash

set -e

function downloadOlm {
	curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/"${OLM_VERSION}"/install.sh | bash -s "$OLM_VERSION" || exit 1	
}

function installOperator {
	kubectl create -f https://operatorhub.io/install/aerospike-kubernetes-operator.yaml
	count=0
	csvStateFinal=""
	while :
	do
		csvState=($(kubectl get csv -n operators --no-headers | awk '{ if (match($6, "aerospike-kubernetes-operator") > 0 ) { print $7 } else { print $6 }}'))
		if [ "${csvState}" = "Succeeded" ]; then
			echo "Operator CSV is installed successfully!"
			break
		fi
		echo "CSV not ready yet... polling..."
		[ ! -z "$csvState" ] && echo "$csvState"
		((count += 1))
		sleep 3

		if ((count == 30)); then
			echo "Not sure if CSV installed. Please verify."
			kubectl get csv -n operators
			exit 1
		fi
	done
}

function createNamespaceAndServiceAccount {
	kubectl create namespace aerospike
	kubectl -n aerospike create serviceaccount aerospike-operator-controller-manager
	kubectl create clusterrolebinding aerospike-cluster --clusterrole=aerospike-cluster --serviceaccount=aerospike:aerospike-operator-controller-manager
	kubectl patch clusterrolebindings.rbac.authorization.k8s.io $(kubectl get clusterrolebindings.rbac.authorization.k8s.io  | grep aerospike-kubernetes-operator | grep -v -- "-opera-" | grep -v -- "default-ns" | cut -f 1 -d " ") --patch \
		'{"subjects":[
		{"kind": "ServiceAccount", "name": "aerospike-operator-controller-manager","namespace":"operators"},
		{"kind": "ServiceAccount", "name": "aerospike-operator-controller-manager","namespace": "aerospike"}
		]}' || exit 2
}

function createSecrets {
	kubectl -n aerospike create secret generic aerospike-secret --from-file=/root/features.conf
	kubectl  -n aerospike create secret generic auth-secret --from-literal=password='admin123'
}

function deployOpenEBS {
	kubectl apply -f https://openebs.github.io/charts/openebs-operator.yaml
}

function configureAmazonAutoscaler {
	# Patch the deployment to add the cluster-autoscaler.kubernetes.io/safe-to-evict annotation to the Cluster Autoscaler pods with the following command.

	kubectl patch -n kube-system deployment.apps/cluster-autoscaler --type "json" -p "[
        { 'op': 'add', 'path': '/spec/template/metadata/annotations/cluster-autoscaler.kubernetes.io~1safe-to-evict', 'value': 'false' }
        ]"

	# Remove the last command in array to overwrite with our cluster name:
	# spec:
	#  containers:
	#  - command
	#    - ./cluster-autoscaler
	#    - --v=4
	#    - --stderrthreshold=info
	#    - --cloud-provider=aws
	#    - --skip-nodes-with-local-storage=false
	#    - --expander=least-waste
	#    - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/YOUR_CLUSTER_NAME_HERE
	#    - --balance-similar-node-groups
	#    - --skip-nodes-with-system-pods=false
	kubectl patch -n kube-system deployment.apps/cluster-autoscaler --type "json" -p '[{"op": "remove", "path": "/spec/template/spec/containers/0/command/-1" }]'

	# Add our cluster name option and last two parameters 
	# --balance-similar-node-groups
	# --skip-nodes-with-system-pods=false
	kubectl patch -n kube-system deployment.apps/cluster-autoscaler --type "json" -p "[
	{'op': 'add', 'path': '/spec/template/spec/containers/0/command/-', 'value': '--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${CLUSTER_NAME}'},
	{'op': 'add', 'path': '/spec/template/spec/containers/0/command/-', 'value': '--balance-similar-node-groups'},
	{'op': 'add', 'path': '/spec/template/spec/containers/0/command/-', 'value': '--skip-nodes-with-system-pods=false' },
	]"
	
	# Set deployment image for our cluster version
	kubectl set image deployment cluster-autoscaler -n kube-system cluster-autoscaler=registry.k8s.io/autoscaling/cluster-autoscaler:"v${K8S_VERSION}.0"
}

function usage {
        echo "Usage: $0 -n CLUSTER_NAME -v K8S_VERSION [-o OLM_VERSION, -E] [ -R ]"
        echo ""
        echo "-n) EKS cluster name to attach to"
        echo "-v) Kubernetes version to use when attaching via gaiakube"
	echo "-o) OLM version to install: (Default: v0.25.0)"
	echo "-A) Install and Configure Amazon cluster-autoscaler (Default: false)"
	echo "-E) Install OpenEBS Operator (Default: false)"
	echo "-R) Run cleanup to remove OLM, operators, and aerospike namespace"
}
function exit_abnormal {
        usage
        exit 1
}

function parseArgs {
	while getopts "n:v:o:ARE" options; do
                case "${options}" in
                n)
                        CLUSTER_NAME="${OPTARG}" # set $NAME to specified value.
                        ;;
                v)
                        K8S_VERSION="${OPTARG}"
                        ;;
		o)	
			OLM_VERSION="${OPTARG}"
			;;
		R)	CLEANUP=1
			;;
		E)	
			INSTALL_OPENEBS=1
			;;
		A) 
			AUTOSCALER=1
			;;
                :) # If expected argument omitted:
                        echo "Error: -${OPTARG} requires an argument."
                        exit_abnormal # Exit abnormally.
                        ;;
                *)
                        exit_abnormal
                        ;;
                esac
        done
}

function cleanUp {
	set +e
	kubectl delete -f https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_VERSION}/crds.yaml
	kubectl delete -f https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_VERSION}/olm.yaml
	kubectl delete namespace aerospike
	kubectl delete clusterrolebinding aerospike-cluster
	echo "Please verify the olm, operators, and aerospike namespace are deleted"
	kubectl get namespace	
	exit 0
}

function main {
	parseArgs "$@" 
	[ "$CLUSTER_NAME" = "" ] && exit_abnormal
	[ "$K8S_VERSION" = "" ] && exit_abnormal
	if [ ! -f /root/features.conf ]; then
		echo "/root/features.conf is not found! Please ensure features.conf file exists and has proper permissions."
		exit 3
	fi
	gaiakube "$K8S_VERSION" "$CLUSTER_NAME"
       	[ $? -ne 0 ] && echo "Failed to connect with gaiakube" && exit 5
	[ $CLEANUP -eq 1 ] && cleanUp
	downloadOlm
	installOperator
	createNamespaceAndServiceAccount
	createSecrets
	[ $INSTALL_OPENEBS -eq 1 ] && deployOpenEBS
	[ $AUTOSCALER -eq 1 ] && configureAmazonAutoscaler
	kubectl get all -n aerospike
}

CLUSTER_NAME=
K8S_VERSION=
OLM_VERSION="v0.25.0"
CLEANUP=0
INSTALL_OPENEBS=0
AUTOSCALER=0

main "$@"

