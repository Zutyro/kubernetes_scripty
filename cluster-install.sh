#! /usr/bin/env bash
if [ $# -ne 1 ] 
then
    echo "Chyba: Argument musi byt jeden"
    exit
else
    if ! [ -f "$1" ] 
    then
        echo "Chyba: Argument musi byt textovy soubor"
        exit
    fi
fi    


master_install () {
    echo $1
    echo "Tohle je master node"
}

worker_install () {
    echo $1
    echo "Tohle je worker node"
}

file="$1"

while IFS=" " read -r line; do
    node=($line)
    if [ ${node[1]} = "master" ]
    then
        master_install ${node[0]}
    fi
    if [ ${node[1]} = "worker" ]
    then
        worker_install ${node[0]}
    fi
done < "$file"
