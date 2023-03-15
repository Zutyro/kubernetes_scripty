#!/usr/bin/env bash

tar Cxzvf /usr/local ./runtime_downloads/containerd-1.6.15-linux-amd64.tar.gz

mv ./runtime_downloads/containerd.service /etc/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd

mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin ./runtime_downloads/cni-plugins-linux-amd64-v1.2.0.tgz

install -m 755 ./runtime_downloads/runc.amd64 /usr/local/sbin/runc

mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml

apt-get install rpl
rpl "SystemdCgroup = false" "SystemdCgroup = true" /etc/containerd/config.toml

systemctl restart containerd
