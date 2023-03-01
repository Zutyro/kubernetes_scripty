#!/usr/bin/env bash

apt-get install iptables-persistent

/sbin/iptables -A INPUT -p tcp --dport 10250 -j ACCEPT
/sbin/iptables -A INPUT -p tcp -m multiport --dports 30000:32767 -j ACCEPT


/sbin/iptables-save > /etc/iptables/rules.v4
