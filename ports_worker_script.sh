#!/usr/bin/env bash

sudo apt-get -y install iptables-persistent

sudo /sbin/iptables -A INPUT -p tcp --dport 10250 -j ACCEPT
sudo /sbin/iptables -A INPUT -p tcp -m multiport --dports 30000:32767 -j ACCEPT


sudo /sbin/iptables-save | sudo tee /etc/iptables/rules.v4
