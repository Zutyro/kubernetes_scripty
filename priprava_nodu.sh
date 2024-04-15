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


master_edit() {
    old_hostname=$(ssh ${node[0]} -n -o 'StrictHostKeyChecking accept-new' 'echo $HOSTNAME')
    echo $old_hostname
    mastercount=$(($mastercount + 1))  
    echo $mastercount
    ssh ${node[0]} -n "sudo hostnamectl set-hostname master$mastercount"
    ssh ${node[0]} -n "sudo sed -i s/$old_hostname/master$mastercount/g /etc/hosts"
    ssh ${node[0]} -n "sudo shutdown -r now"
}

worker_edit() {
    old_hostname=$(ssh ${node[0]} -n -o 'StrictHostKeyChecking accept-new' 'echo $HOSTNAME')
    echo $old_hostname
    workercount=$(($workercount + 1))
    echo $workercount
    ssh ${node[0]} -n "sudo hostnamectl set-hostname worker$workercount"
    ssh ${node[0]} -n "sudo sed -i s/$old_hostname/worker$workercount/g /etc/hosts"
    ssh ${node[0]} -n "sudo shutdown -r now"
}


file="$1"

echo Zmena hostname vsech nodu


while IFS=" " read -r line; do
    node=($line)
    if [ ${node[1]} = "master" ]
    then
        echo Priprava master nodu
        master_edit $node
    fi
    if [ ${node[1]} = "worker" ]
    then
        echo Priprava worker nodu
        worker_edit $node
    fi
done < "$file"