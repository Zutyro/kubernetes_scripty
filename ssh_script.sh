#! /usr/bin/env bash

if [ $# -lt 3 ]
	then
		echo "Error: Chybejici argumeny. Je potreba vlozit ip adresu, jmeno a heslo pro ssh."
		exit
fi

echo "Vlozena ip adresa: $1"
echo "Vlozeno heslo: $2"

sshpass -p $3 ssh $2@$1 "mkdir /home/zutyro/test"