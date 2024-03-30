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
    echo Vytvareni pravidel pro otevreni portu
    ssh ${node[0]} "sudo nft add table inet kubernetes"
    ssh ${node[0]} "sudo nft 'add chain inet kubernetes input { type filter hook input priority 0 ; }'"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 6443 accept"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 2379 accept"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 2380 accept"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 10250 accept"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 10259 accept"
    ssh ${node[0]} "sudo nft add rule inet kubernetes input tcp dport 10257 accept"
    ssh ${node[0]} 'echo flush ruleset | sudo tee /etc/nftables.conf'
    ssh ${node[0]} 'sudo nft list ruleset | sudo tee -a /etc/nftables.conf'


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
