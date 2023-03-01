#!/usr/bin/env bash

wget \
https://github.com/containerd/containerd/releases/download/v1.6.15/containerd-1.6.15-linux-amd64.tar.gz \
&& wget \
https://raw.githubusercontent.com/containerd/containerd/main/containerd.service \
&& wget \
https://github.com/opencontainers/runc/releases/download/v1.1.4/runc.amd64 \
&& wget \
https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-amd64-v1.2.0.tgz

tar Cxzvf /usr/local containerd-1.6.15-linux-amd64.tar.gz

mv containerd.service /etc/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd

mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.2.0.tgz

mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml

apt-get install rpl
rpl "SystemdCgroup = false" "SystemdCgroup = true" /etc/containerd/config.toml

systemctl restart containerd
