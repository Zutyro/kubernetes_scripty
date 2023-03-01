#!/usr/bin/env bash

apt-get install iptables-persistent

iptables -A INPUT -p tcp --dport 6443 -j ACCEPT
iptables -A INPUT -p tcp --dport 2379 -j ACCEPT
iptables -A INPUT -p tcp --dport 2380 -j ACCEPT
iptables -A INPUT -p tcp --dport 10250 -j ACCEPT
iptables -A INPUT -p tcp --dport 10259 -j ACCEPT
iptables -A INPUT -p tcp --dport 10257 -j ACCEPT

iptables-save > /etc/iptables/rules.v4
