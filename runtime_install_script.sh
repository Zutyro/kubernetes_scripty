#!/usr/bin/env bash

sudo tar Cxzvf /usr/local ./runtime_downloads/containerd-1.6.15-linux-amd64.tar.gz

sudo mv ./runtime_downloads/containerd.service /etc/systemd/system/containerd.service
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin ./runtime_downloads/cni-plugins-linux-amd64-v1.2.0.tgz

sudo install -m 755 ./runtime_downloads/runc.amd64 /usr/local/sbin/runc

sudo mkdir /etc/containerd
sudo containerd config default > /etc/containerd/config.toml

sudo apt-get -y install rpl
sudo rpl "SystemdCgroup = false" "SystemdCgroup = true" /etc/containerd/config.toml

sudo systemctl restart containerd
