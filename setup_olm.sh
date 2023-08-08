#!/bin/bash

set -e

function downloadOlm {
	curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.21.2/install.sh | bash -s "$OLM_VERSION" || exit 1	
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


function usage {
        echo "Usage: $0 -n CLUSTER_NAME -v K8S_VERSION [-o OLM_VERSION] [ -R ]"
        echo ""
        echo "-n) EKS cluster name to attach to"
        echo "-v) Kubernetes version to use when attaching via gaiakube"
	echo "-o) OLM version to install: Default v0.21.2"
	echo "-R) Run cleanup to remove OLM, operators, and aerospike namespace"
}
function exit_abnormal {
        usage
        exit 1
}

function parseArgs {
        while getopts "n:v:oR" options; do
                case "${options}" in
                n)
                        CLUSTER_NAME=${OPTARG} # set $NAME to specified value.
                        ;;
                v)
                        K8S_VERSION="${OPTARG}"
                        ;;
		o)	OLM_VERSION="${OPTARG}"
			;;
		R)	CLEANUP=1
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
	echo "Please verify the olm, operators, and aerospike namespace are deleted"
	kubectl get namespace	
	exit 0
}

function main {
	parseArgs "$@" 
	[ "$CLUSTER_NAME" = "" ] && exit_abnormal
	[ "$K8S_VERSION" = "" ] && exit_abnormal
	gaiakube "$K8S_VERSION" "$CLUSTER_NAME"
       	[ $? -ne 0 ] && echo "Failed to connect with gaiakube" && exit 5
	[ $CLEANUP -eq 1 ] && cleanUp
	downloadOlm
	installOperator
	createNamespaceAndServiceAccount
	createSecrets
	kubectl get all -n aerospike
}

CLUSTER_NAME=
K8S_VERSION=
OLM_VERSION="v0.21.2"
CLEANUP=0

main "$@"

