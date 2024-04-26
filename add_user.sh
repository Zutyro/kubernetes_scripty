#!/usr/bin/env bash
if [ $# -ne 1 ]
then
    echo "Chyba: Argumenty musi byt 1"
    exit 1
else
    if ! [ -f "$1" ] 
    then
        echo Chyba: Argument musi byt textovy soubor
        exit 1
    fi
fi    


create_user () {
    user=($1)
    openssl genrsa -out "${user[0]}".pem
    openssl req -new -key "${user[0]}".pem -out "${user[0]}".csr -subj /CN="${user[0]}"
    request=$(cat "${user[0]}".csr | base64 | tr -d '\n')
    cat <<EOF | tee "${user[0]}"-csr.yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
 name: user-request-${user[0]}
spec:
 groups:
 - system:authenticated
 request: $request
 signerName: kubernetes.io/kube-apiserver-client
 expirationSeconds: 315569260
 usages:
 - digital signature
 - key encipherment
 - client auth
EOF

    kubectl create -f "${user[0]}"-csr.yaml
    kubectl certificate approve user-request-"${user[0]}"
    kubectl get csr user-request-"${user[0]}" -o jsonpath='{.status.certificate}' | base64 -d > "${user[0]}"-user.crt
    api_server=$(cat ~/.kube/config | grep -i server | sed 's/.*\(https.*\)/\1/g')
    
    kubectl --kubeconfig ~/.kube/config-"${user[0]}" config set-cluster kubernetes --server="$api_server" --certificate-authority <(cat ~/.kube/config | grep -i certificate-authority | sed 's/.*: //g' | base64 -d) --embed-certs
    kubectl --kubeconfig ~/.kube/config-"${user[0]}" config set-credentials "${user[0]}" --client-certificate="${user[0]}"-user.crt --client-key="${user[0]}".pem --embed-certs=true
    kubectl --kubeconfig ~/.kube/config-"${user[0]}" config set-context default --cluster=kubernetes --user="${user[0]}"
    kubectl --kubeconfig ~/.kube/config-"${user[0]}" config use-context default

    while IFS=',' read -ra var; do
        for ((i = 0; i < ${#var[$i]}; ++i)); do
            if [ $i = 0 ]
            then
                if [ "${var[i]}" = "core" ]
                then
                    groups="[\""
                    continue
                fi
                groups="[\"${var[i]}"
                if [ "${var[i]}" = "all" ]
                then
                    groups="[\"*\"]"
                    break 2
                fi
            else
                if [ "${var[i]}" = "core" ]
                then
                    groups="$groups\", \""
                    continue
                fi
                groups="$groups\", \"${var[i]}"
                if [ "${var[i]}" = "all" ]
                then
                    groups="[\"*\"]"
                    break 2
                fi
            fi
        done
        groups="$groups\"]"
    done <<< "${user[2]}"
    while IFS=',' read -ra var; do
        for ((i = 0; i < ${#var[$i]}; ++i)); do
            if [ $i = 0 ]
            then
                objects="[\"${var[i]}"
                if [ "${var[i]}" = "all" ]
                then
                    objects="[\"*\"]"
                    break 2
                fi
            else
                objects="$objects\", \"${var[i]}"
                if [ "${var[i]}" = "all" ]
                then
                    objects="[\"*\"]"
                    break 2
                fi
            fi
        done
        objects="$objects\"]"
    done <<< "${user[3]}"
    while IFS=',' read -ra var; do
        for ((i = 0; i < ${#var[$i]}; ++i)); do
            if [ $i = 0 ]
            then
                verbs="[\"${var[i]}"
                if [ "${var[i]}" = "all" ]
                then
                    verbs="[\"*\"]"
                    break 2
                fi
            else
                verbs="$verbs\", \"${var[i]}"
                if [ "${var[i]}" = "all" ]
                then
                    verbs="[\"*\"]"
                    break 2
                fi
            fi
        done
        verbs="$verbs\"]"
    done <<< "${user[4]}"

    if [ "${user[1]}" = "cluster" ]
    then
        cat <<EOF | tee ${user[0]}-clusterrbac.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
 name: ${user[0]}
rules:
 - apiGroups: $groups
   resources: $objects
   verbs: $verbs
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
 name: ${user[0]}
subjects:
 - kind: User
   name: ${user[0]}
   apiGroup: rbac.authorization.k8s.io
roleRef:
   apiGroup: rbac.authorization.k8s.io
   kind: ClusterRole
   name: ${user[0]}
EOF
        kubectl create -f "${user[0]}-clusterrbac.yaml"
    else
        cat <<EOF | tee ${user[0]}-rbac.yaml
apiVersion: v1
kind: Namespace
metadata:
 name: ${user[1]}
spec: {}
status: {}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
 name: ${user[0]}
 namespace: ${user[1]}
rules:
 - apiGroups: $groups
   resources: $objects
   verbs: $verbs
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
 name: ${user[0]}
 namespace: ${user[1]}
subjects:
 - kind: User
   name: ${user[0]}
   apiGroup: rbac.authorization.k8s.io
roleRef:
   apiGroup: rbac.authorization.k8s.io
   kind: Role
   name: ${user[0]}
EOF
        kubectl create -f "${user[0]}-rbac.yaml"
    fi

}

file="$1"
echo Tvorba uzivatelu clusteru
while IFS=" " read -r line; do
    create_user "$line"
done < "$file"