#! /usr/bin/env bash
if [ $# -ne 1 ] 
then
    echo Chyba: Argument musi byt jeden
    exit
else
    if ! [ -f "$1" ] 
    then
        echo Chyba: Argument musi byt textovy soubor
        exit
    fi
fi    


master_install () {
    node=$1
    echo Zpracovavani nodu ${node[0]}

    echo Vytvareni pravidel pro otevreni portu
    ssh ${node[0]} "sudo nft add table inet kubernetes"
    ssh ${node[0]} "sudo nft 'add chain inet kubernetes input { type filter hook input priority 0 ; }'"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 6443 accept"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 2379 accept"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 2380 accept"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 10250 accept"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 10259 accept"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 10257 accept"
    ssh ${node[0]} "echo flush ruleset | sudo tee /etc/nftables.conf"
    ssh ${node[0]} "sudo nft list ruleset | sudo tee -a /etc/nftables.conf"


    echo Stahovani container runtimu
    ssh ${node[0]} "sudo apt-get install wget"
    ssh ${node[0]} "sudo apt-get install rpl"
    ssh ${node[0]} "mkdir ~/runtime_downloads"

    files=("containerd-1.7.14-linux-amd64.tar.gz" "runc.amd64" "cni-plugins-linux-amd64-v1.4.1.tgz")
    file_downloads=("https://github.com/containerd/containerd/releases/download/v1.7.14" "https://github.com/opencontainers/runc/releases/download/v1.1.12" "https://github.com/containernetworking/plugins/releases/download/v1.4.1")
    shasums=("containerd-1.7.14-linux-amd64.tar.gz.sha256sum" "runc.sha256sum" "cni-plugins-linux-amd64-v1.4.1.tgz.sha256")

    for i in $(seq 0 2);
    do
        echo "Stahuji ${files[$i]}"
        while
            ssh ${node[0]} "wget -q -P runtime_downloads ${file_downloads[$i]}/${shasums[$i]}"
            ssh ${node[0]} "wget -q -P runtime_downloads ${file_downloads[$i]}/${files[$i]}"
            echo "Overuji ${files[$i]} sha"
            ssh ${node[0]} "cd runtime_downloads;shasum -c ~/runtime_downloads/${shasums[$i]}"
            [ ! $? -eq 0 ]
        do 
            echo "${files[$i]} overeni neuspelo, stahuji znovu"
            ssh ${node[0]} "rm runtime_downloads/${files[$i]}"
            ssh ${node[0]} "rm runtime_downloads/${shasums[$i]}"
        done
        echo "${files[$i]} uspesne stahnut a overen"
    done

    ssh ${node[0]} wget -q -P runtime_downloads https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
    echo "Containerd service stahnut bez overeni"

    echo Instalace container runtimu
    ssh ${node[0]} "sudo tar Cxzvf /usr/local ./runtime_downloads/${files[$0]}"

    ssh ${node[0]} "sudo mv ./runtime_downloads/containerd.service /etc/systemd/system/containerd.service"
    ssh ${node[0]} "sudo systemctl daemon-reload"
    ssh ${node[0]} "sudo systemctl enable --now containerd"

    ssh ${node[0]} "sudo mkdir -p /opt/cni/bin"
    ssh ${node[0]} "sudo tar Cxzvf /opt/cni/bin ./runtime_downloads/${files[$2]}"

    ssh ${node[0]} "sudo install -m 755 ./runtime_downloads/${files[$1]} /usr/local/sbin/runc"

    ssh ${node[0]} "sudo mkdir /etc/containerd"
    ssh ${node[0]} "sudo containerd config default > /etc/containerd/config.toml"

    ssh ${node[0]} "sudo apt-get -y install rpl"
    ssh ${node[0]} 'sudo rpl "SystemdCgroup = false" "SystemdCgroup = true" /etc/containerd/config.toml'

    ssh ${node[0]} "sudo systemctl restart containerd"


}

worker_install () {
    node=$1
    echo ${node[0]}
    echo Tohle je ${node[1]} node
}

file="$1"

while IFS=" " read -r line; do
    node=($line)
    if [ ${node[1]} = "master" ]
    then
        master_install $node
    fi
    if [ ${node[1]} = "worker" ]
    then
        worker_install $node
    fi
done < "$file"
