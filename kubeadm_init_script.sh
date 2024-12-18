#! /usr/bin/env bash

touch ~/kubeadm-config.yaml

cat <<EOF > ~/kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
networking:
 podSubnet: "10.244.0.0/16"
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF

sudo kubeadm init --config ~/kubeadm-config.yaml