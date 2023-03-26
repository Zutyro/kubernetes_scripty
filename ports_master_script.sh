#!/usr/bin/env bash

sudo apt-get -y install iptables-persistent

sudo /sbin/iptables -A INPUT -p tcp --dport 6443 -j ACCEPT
sudo /sbin/iptables -A INPUT -p tcp --dport 2379 -j ACCEPT
sudo /sbin/iptables -A INPUT -p tcp --dport 2380 -j ACCEPT
sudo /sbin/iptables -A INPUT -p tcp --dport 10250 -j ACCEPT
sudo /sbin/iptables -A INPUT -p tcp --dport 10259 -j ACCEPT
sudo /sbin/iptables -A INPUT -p tcp --dport 10257 -j ACCEPT

sudo /sbin/iptables-save > tee /etc/iptables/rules.v4
