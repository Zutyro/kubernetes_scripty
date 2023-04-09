#! /usr/bin/env bash

if [ $# -lt 4 ]
	then
		echo "Error: Chybejici argumenty. Je potreba vlozit ip adresu, jmeno a heslo pro ssh, a zda li se jedna o master nebo worker node (1 nebo 2). 4 argumenty celkove."
		exit
fi

echo "Vlozena ip adresa: $1"
echo "Vlozeno jmeno: $2"
echo "Vlozeno heslo: $3"

sshpass -p $3 ssh $2@$1 "mkdir test"

if [ $4 -eq 1 ]
	then
		sshpass -p $3 ssh $2@$1 "mkdir cripts"
		sshpass -p $3 scp "~/scripts/ports_master_script.sh" "$2@$1:~/scripts"
		sshpass -p $3 ssh $2@$1 "echo $3 | sudo -S bash ~/scripts/ports_master_script.sh"
		sshpass -p $3 scp "~/scripts/sysctl_config_script.sh" "$2@$1:~/scripts"
		sshpass -p $3 ssh $2@$1 "echo $3 | sudo -S bash ~/scripts/sysctl_config_script.sh"
		sshpass -p $3 scp "~/scripts/runtime_download_script.sh" "$2@$1:~/scripts"
		sshpass -p $3 ssh $2@$1 "echo $3 | sudo -S bash ~/scripts/runtime_download_script.sh"
		sshpass -p $3 scp "~/scripts/runtime_install_script.sh" "$2@$1:~/scripts"
		sshpass -p $3 ssh $2@$1 "echo $3 | sudo -S bash ~/scripts/runtime_install_script.sh"
		sshpass -p $3 scp "~/scripts/kubeadm_install_script.sh" "$2@$1:~/scripts"
		sshpass -p $3 ssh $2@$1 "echo $3 | sudo -S bash ~/scripts/kubeadm_install_script.sh"
		sshpass -p $3 scp "~/scripts/kubeadm_init_script.sh" "$2@$1:~/scripts"
		sshpass -p $3 ssh $2@$1 "echo $3 | sudo -S bash ~/scripts/kubeadm_init_script.sh"
fi