#! /usr/bin/env bash

apt-get install wget
mkdir runtime_downloads

files=("containerd-1.6.15-linux-amd64.tar.gz" "runc.amd64" "cni-plugins-linux-amd64-v1.2.0.tgz")
file_downloads=("https://github.com/containerd/containerd/releases/download/v1.6.15" "https://github.com/opencontainers/runc/releases/download/v1.1.4" "https://github.com/containernetworking/plugins/releases/download/v1.2.0")
shasums=("containerd-1.6.15-linux-amd64.tar.gz.sha256sum" "runc.sha256sum" "cni-plugins-linux-amd64-v1.2.0.tgz.sha256")

for i in $(seq 0 2);
do
	echo "stahuji ${files[$i]}"
	while
		wget -q -P runtime_downloads \
		${file_downloads[$i]}/${shasums[$i]}
		wget -q -P runtime_downloads \
		${file_downloads[$i]}/${files[$i]}
		echo "overuji ${files[$i]} sha"
		cd runtime_downloads
		shasum -c ./${shasums[$1]}
		cd ..
		[ ! $? -eq 0 ]
	do 
		echo "${files[$i]} overeni neuspelo, stahuji znovu"
		rm ./runtime_downloads/$file
		rm ./runtime_downloads/$shasum
	done
	echo "${file[$i]} uspesne stahnut a overen"
done

wget -q -P runtime_downloads \
https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
echo "containerd service stahnut bez overeni"
