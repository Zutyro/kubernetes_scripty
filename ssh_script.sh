#! /usr/bin/env bash

if [ $# -lt 4 ]
	then
		echo "Error: Chybejici argumenty. Je potreba vlozit ip adresu, jmeno a heslo pro ssh, a zda li se jedna o master nebo worker node (1 nebo 2). 4 argumenty celkove."
		exit
fi

echo "Vlozena ip adresa: $1"
echo "Vlozeno jmeno: $2"
echo "Vlozeno heslo: $3"

sshpass -p $3 ssh $2@$1 "mkdir /home/zutyro/test"

if [ $4 -eq 1 ]
	then
		sshpass -p $3 ssh $2@$1 "mkdir /home/zutyro/scripts"
		sshpass -p $3 scp "/home/zutyro/scripts/ports_master_script.sh" "$2@$1:~/scripts"
		sshpass -p $3 ssh $2@$1 "echo $3 | sudo -S bash /home/zutyro/scripts/ports_master_script.sh"
		sshpass -p $3 scp "/home/zutyro/scripts/sysctl_config_script.sh" "$2@$1:~/scripts"
		sshpass -p $3 ssh $2@$1 "echo $3 | sudo -S bash /home/zutyro/scripts/sysctl_config_script.sh"
fi