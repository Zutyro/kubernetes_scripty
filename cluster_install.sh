#! /usr/bin/env bash
highavailability=false
taint=false
file_passed=false
while getopts ':h:tf:' OPTION; do
    case "$OPTION" in
        h)
            highavailability=true
            loadbalancer="$OPTARG"
            ;;
        t)
            taint=true
            ;;
        f)
            file_passed=true
            file="$OPTARG"
            ;;
        ?)
            echo "Pouziti: $(basename $0) [-t] [-h LOADBALANCER-IP] [-f SOUBOR]"
            exit 1
            ;;
    esac
done

if [ $file_passed = false ]
then 
    echo Chyba: Musi byt predan soubor nodu
    exit 1
else
    if ! [ -f "$file" ] 
    then
        echo Chyba: Soubor argumentu -f musi byt textovy soubor
        exit 1
    fi
fi

master_install () {
    node=$1
    echo Zpracovavani nodu ${node[0]}

    echo Vytvareni pravidel pro otevreni portu
    ssh ${node[0]} -n -o 'StrictHostKeyChecking accept-new' "sudo apt-get -y install iptables"

    ssh ${node[0]} -n "sudo update-alternatives --set iptables /usr/sbin/iptables-legacy"
    ssh ${node[0]} -n "sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy"
    ssh ${node[0]} -n "sudo apt-get -y install iptables-persistent"
    ssh ${node[0]} -n "sudo iptables -A INPUT -p tcp --dport 6443 -j ACCEPT"
    ssh ${node[0]} -n "sudo iptables -A INPUT -p tcp --dport 2379 -j ACCEPT"
    ssh ${node[0]} -n "sudo iptables -A INPUT -p tcp --dport 2380 -j ACCEPT"
    ssh ${node[0]} -n "sudo iptables -A INPUT -p tcp --dport 10250 -j ACCEPT"
    ssh ${node[0]} -n "sudo iptables -A INPUT -p tcp --dport 10259 -j ACCEPT"
    ssh ${node[0]} -n "sudo iptables -A INPUT -p tcp --dport 10257 -j ACCEPT"
    ssh ${node[0]} -n "sudo iptables-save | sudo tee /etc/iptables/rules.v4"

    echo Aktivace kernel modulu a parametru
    ssh ${node[0]} sudo cat <<EOF | ssh ${node[0]} sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
EOF

    ssh ${node[0]} -n "sudo /sbin/modprobe overlay"
    ssh ${node[0]} -n "sudo /sbin/modprobe br_netfilter"

    ssh ${node[0]} sudo cat <<EOF | ssh ${node[0]} sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
EOF
    ssh ${node[0]} -n "sudo /sbin/sysctl --system"


    echo Stahovani container runtimu
    ssh ${node[0]} -n "sudo apt-get -y install wget"
    ssh ${node[0]} -n "sudo apt-get -y install rpl"
    ssh ${node[0]} -n "mkdir ~/runtime_downloads"

    files=("containerd-1.7.14-linux-amd64.tar.gz" "runc.amd64" "cni-plugins-linux-amd64-v1.4.1.tgz")
    file_downloads=("https://github.com/containerd/containerd/releases/download/v1.7.14" "https://github.com/opencontainers/runc/releases/download/v1.1.12" "https://github.com/containernetworking/plugins/releases/download/v1.4.1")
    shasums=("containerd-1.7.14-linux-amd64.tar.gz.sha256sum" "runc.sha256sum" "cni-plugins-linux-amd64-v1.4.1.tgz.sha256")

    for i in $(seq 0 2);
    do
        echo "Stahuji ${files[$i]}"
        while
            ssh ${node[0]} -n "wget -q -P runtime_downloads ${file_downloads[$i]}/${shasums[$i]}"
            ssh ${node[0]} -n "wget -q -P runtime_downloads ${file_downloads[$i]}/${files[$i]}"
            echo "Overuji ${files[$i]} sha"
            ssh ${node[0]} -n "grep \"${files[$i]}\" runtime_downloads/${shasums[$i]} > runtime_downloads/shasumfile"
            ssh ${node[0]} -n "cd runtime_downloads;shasum -c ~/runtime_downloads/shasumfile"
            [ ! $? -eq 0 ]
        do 
            echo "${files[$i]} overeni neuspelo, stahuji znovu"
            ssh ${node[0]} -n "rm runtime_downloads/${files[$i]}"
            ssh ${node[0]} -n "rm runtime_downloads/${shasums[$i]}"
        done
        echo "${files[$i]} uspesne stahnut a overen"
    done

    ssh ${node[0]} -n wget -q -P runtime_downloads https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
    echo "Containerd service stahnut bez overeni"

    echo Instalace container runtimu
    ssh ${node[0]} -n "sudo tar Cxzvf /usr/local ./runtime_downloads/${files[0]}"

    ssh ${node[0]} -n "sudo mv ./runtime_downloads/containerd.service /etc/systemd/system/containerd.service"
    ssh ${node[0]} -n "sudo systemctl daemon-reload"
    ssh ${node[0]} -n "sudo systemctl enable --now containerd"

    ssh ${node[0]} -n "sudo mkdir -p /opt/cni/bin"
    ssh ${node[0]} -n "sudo tar Cxzvf /opt/cni/bin ./runtime_downloads/${files[2]}"

    ssh ${node[0]} -n "sudo install -m 755 ./runtime_downloads/${files[1]} /usr/local/sbin/runc"

    ssh ${node[0]} -n "sudo mkdir /etc/containerd"
    ssh ${node[0]} -n "sudo containerd config default | sudo tee /etc/containerd/config.toml"

    ssh ${node[0]} -n "sudo apt-get -y install rpl"
    ssh ${node[0]} -n 'sudo rpl "SystemdCgroup = false" "SystemdCgroup = true" /etc/containerd/config.toml'

    ssh ${node[0]} -n "sudo systemctl restart containerd"

   
    echo Instalace kubeadm, kubectl a kubelet

    ssh ${node[0]} -n sudo apt-get update
    ssh ${node[0]} -n sudo apt-get install -y curl apt-transport-https ca-certificates

    ssh ${node[0]} -n sudo mkdir /etc/apt/keyrings

    ssh ${node[0]} -n "sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o  /etc/apt/keyrings/kubernetes-archive-keyring.gpg"

    ssh ${node[0]} -n "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list"

    ssh ${node[0]} -n sudo apt-get update
    ssh ${node[0]} -n sudo apt-get install -y kubelet kubeadm kubectl
    ssh ${node[0]} -n sudo apt-mark hold kubelet kubeadm kubectl

    ssh ${node[0]} -n sudo swapoff -a
    ssh ${node[0]} -n "sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"


}

worker_install () {
    node=$1
    echo Zpracovavani nodu ${node[0]}

    echo Vytvareni pravidel pro otevreni portu
    ssh ${node[0]} -n -o 'StrictHostKeyChecking accept-new' "sudo apt-get -y install iptables"

    ssh ${node[0]} -n "sudo update-alternatives --set iptables /usr/sbin/iptables-legacy"
    ssh ${node[0]} -n "sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy"
    ssh ${node[0]} -n "sudo apt-get -y install iptables-persistent"
    ssh ${node[0]} -n "sudo iptables -A INPUT -p tcp --dport 10250 -j ACCEPT"
    ssh ${node[0]} -n "sudo iptables -A INPUT -p tcp -m multiport --dports 30000:32767 -j ACCEPT"
    ssh ${node[0]} -n "sudo iptables-save | sudo tee /etc/iptables/rules.v4"

    echo Aktivace kernel modulu a parametru
    ssh ${node[0]} sudo cat <<EOF | ssh ${node[0]} sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
EOF

    ssh ${node[0]} -n "sudo /sbin/modprobe overlay"
    ssh ${node[0]} -n "sudo /sbin/modprobe br_netfilter"

    ssh ${node[0]} sudo cat <<EOF | ssh ${node[0]} sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
EOF
    ssh ${node[0]} -n "sudo /sbin/sysctl --system"


    echo Stahovani container runtimu
    ssh ${node[0]} -n "sudo apt-get -y install wget"
    ssh ${node[0]} -n "sudo apt-get -y install rpl"
    ssh ${node[0]} -n "mkdir ~/runtime_downloads"

    files=("containerd-1.7.14-linux-amd64.tar.gz" "runc.amd64" "cni-plugins-linux-amd64-v1.4.1.tgz")
    file_downloads=("https://github.com/containerd/containerd/releases/download/v1.7.14" "https://github.com/opencontainers/runc/releases/download/v1.1.12" "https://github.com/containernetworking/plugins/releases/download/v1.4.1")
    shasums=("containerd-1.7.14-linux-amd64.tar.gz.sha256sum" "runc.sha256sum" "cni-plugins-linux-amd64-v1.4.1.tgz.sha256")

    for i in $(seq 0 2);
    do
        echo "Stahuji ${files[$i]}"
        while
            ssh ${node[0]} -n "wget -q -P runtime_downloads ${file_downloads[$i]}/${shasums[$i]}"
            ssh ${node[0]} -n "wget -q -P runtime_downloads ${file_downloads[$i]}/${files[$i]}"
            echo "Overuji ${files[$i]} sha"
            ssh ${node[0]} -n "grep \"${files[$i]}\" runtime_downloads/${shasums[$i]} > runtime_downloads/shasumfile"
            ssh ${node[0]} -n "cd runtime_downloads;shasum -c ~/runtime_downloads/shasumfile"
            [ ! $? -eq 0 ]
        do 
            echo "${files[$i]} overeni neuspelo, stahuji znovu"
            ssh ${node[0]} -n "rm runtime_downloads/${files[$i]}"
            ssh ${node[0]} -n "rm runtime_downloads/${shasums[$i]}"
        done
        echo "${files[$i]} uspesne stahnut a overen"
    done

    ssh ${node[0]} -n wget -q -P runtime_downloads https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
    echo "Containerd service stahnut bez overeni"

    echo Instalace container runtimu
    ssh ${node[0]} -n "sudo tar Cxzvf /usr/local ./runtime_downloads/${files[0]}"

    ssh ${node[0]} -n "sudo mv ./runtime_downloads/containerd.service /etc/systemd/system/containerd.service"
    ssh ${node[0]} -n "sudo systemctl daemon-reload"
    ssh ${node[0]} -n "sudo systemctl enable --now containerd"

    ssh ${node[0]} -n "sudo mkdir -p /opt/cni/bin"
    ssh ${node[0]} -n "sudo tar Cxzvf /opt/cni/bin ./runtime_downloads/${files[2]}"

    ssh ${node[0]} -n "sudo install -m 755 ./runtime_downloads/${files[1]} /usr/local/sbin/runc"

    ssh ${node[0]} -n "sudo mkdir /etc/containerd"
    ssh ${node[0]} -n "sudo containerd config default | sudo tee /etc/containerd/config.toml"

    ssh ${node[0]} -n "sudo apt-get -y install rpl"
    ssh ${node[0]} -n 'sudo rpl "SystemdCgroup = false" "SystemdCgroup = true" /etc/containerd/config.toml'

    ssh ${node[0]} -n "sudo systemctl restart containerd"


    echo Instalace kubeadm a kubelet

    ssh ${node[0]} -n sudo apt-get update
    ssh ${node[0]} -n sudo apt-get install -y curl apt-transport-https ca-certificates

    ssh ${node[0]} -n sudo mkdir /etc/apt/keyrings

    ssh ${node[0]} -n "sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o  /etc/apt/keyrings/kubernetes-archive-keyring.gpg"

    ssh ${node[0]} -n "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list"

    ssh ${node[0]} -n sudo apt-get update
    ssh ${node[0]} -n sudo apt-get install -y kubelet kubeadm
    ssh ${node[0]} -n sudo apt-mark hold kubelet kubeadm

    ssh ${node[0]} -n sudo swapoff -a
    ssh ${node[0]} -n "sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"

}

cluster_init () {
    node=$1
    if [ $highavailability = false ]
    then
        ssh ${node[0]} -n touch "~/kubeadm-config.yaml"

        ssh ${node[0]} cat <<EOF | ssh ${node[0]} sudo tee ~/kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
networking:
 podSubnet: "10.244.0.0/16"
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF
    else
        ssh ${node[0]} -n touch "~/kubeadm-config.yaml"

        ssh ${node[0]} cat <<EOF | ssh ${node[0]} sudo tee ~/kubeadm-config.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta3
networking:
 podSubnet: "10.244.0.0/16"
controlPlaneEndpoint: "$loadbalancer:6443"
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF
    # sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o  /etc/apt/keyrings/kubernetes-archive-keyring.gpg
    # echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    # sudo apt-get update
    # sudo apt-get install -y kubectl
    # sudo apt-mark hold kubectl
    fi
    ssh ${node[0]} -n "sudo kubeadm init --config ~/kubeadm-config.yaml"
    read join_command < <(ssh ${node[0]} -n "sudo kubeadm token create --print-join-command")
    if [ $highavailability = true ]
    then
        read cert_key < <(ssh ${node[0]} -n "sudo kubeadm certs certificate-key")
        ssh ${node[0]} -n "sudo kubeadm init phase upload-certs --upload-certs --certificate-key=$cert_key"
        join_command_master="$join_command --control-plane --certificate-key=$cert_key"
        ssh ${node[0]} -n "sudo rm /etc/kubernetes/admin.conf"
        ssh ${node[0]} -n "sudo rm /etc/kubernetes/super-admin.conf"
        ssh ${node[0]} -n "sudo rm /etc/kubernetes/scheduler.conf"
        ssh ${node[0]} -n "sudo rm /etc/kubernetes/kubelet.conf"
        ssh ${node[0]} -n "sudo rm /etc/kubernetes/controller-manager.conf"
        ssh ${node[0]} -n "sudo kubeadm init phase kubeconfig all"
        
    fi
    ssh ${node[0]} -n "mkdir -p ~/.kube"
    ssh ${node[0]} -n "sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config"
    ssh ${node[0]} -n 'sudo chown $(id -u):$(id -g) ~/.kube/config'
    if [ $highavailability = true ]
    then
        mkdir -p ~/.kube
        scp ${node[0]}:~/.kube/config ~/.kube/config
    fi
    ssh ${node[0]} -n "kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"
}

worker_join () {
    node=$1
    ssh ${node[0]} -n "sudo $join_command"
}

master_join () {
    node=$1
    ssh ${node[0]} -n "sudo $join_command_master"
}

taint_remove () {
    echo taint
}


# echo Instalace potrebnych nastroju na vsechny nody

# while IFS=" " read -r line; do
#     machine=($line)
#     if [ ${machine[1]} = "master" ]
#     then
#         echo Instalace master nodu
#         master_install $machine
#     fi
#     if [ ${machine[1]} = "worker" ]
#     then
#         echo Instalace worker nodu
#         worker_install $machine
#     fi
# done < "$file"

clusterInitialized=false 
while IFS=" " read -r line; do
    machine=($line)
    if [ ${machine[1]} = "master" ] && [ $clusterInitialized = true ] && [  $highavailability = true ]
    then
        echo Pripojeni master nodu do clusteru ${machine[0]}
        master_join $machine
    fi
    if [ ${machine[1]} = "master" ] && [ $clusterInitialized = false ]
    then
        echo Inicializace clusteru na master nodu ${machine[0]}
        cluster_init $machine
        clusterInitialized=true
    fi
done < "$file"

while IFS=" " read -r line; do
    machine=($line)
    if [ ${machine[1]} = "worker" ]
    then
        echo Pripojeni worker nodu do clusteru ${machine[0]}
        worker_join $machine
    fi
done < "$file"

if [ $taint = true ]
then
    while IFS=" " read -r line; do
        machine=($line)
        if [ ${machine[1]} = "master" ]
        then
            echo Odstraneni taintu na master nodech
            taint_remove $machine
        fi
    done < "$file"
fi