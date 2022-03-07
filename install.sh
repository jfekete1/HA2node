#!/bin/bash

echo "Welcome to HA2node intaller!"

echo "To get started, you need to configure a few mandatory options."
host=`hostname`

read -p "Enter the virtual IP address of the primary node (default is 192.168.10.183): " node_vip
node_vip=${node_vip:-192.168.10.183}
read -p "Enter the network mask for virtual IP (default is /24): " node_netmask
node_netmask=${node_netmask:-/24}
read -p "Enter the interface name for virtual IP (default is enp0s3): " node_interface
node_interface=${node_interface:-enp0s3}
read -p "Enter the name of the other node (default is server2): " other_node_name
other_node_name=${other_node_name:-server2}
read -p "Enter the ID of the other node (default is 2): " other_node_id
other_node_id=${other_node_id:-2}
read -p "Enter the IP address of the other node (default is 192.168.10.182): " other_node_ip
other_node_ip=${other_node_ip:-192.168.10.182}

echo "You entered node_vip=$node_vip"
echo "You entered node_netmask=$node_netmask"
echo "You entered node_interface=$node_interface"
echo "You entered other_node_name=$other_node_name"
echo "You entered other_node_id=$other_node_id"
echo "You entered other_node_ip=$other_node_ip"

echo "If the above configuration options are correct, we can continue."
read -p "Continue? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

confloc=`find /etc -name repmgr.conf -print -quit`

cat <<EOT >> $confloc
node_vip='$node_vip'		# The virtual IP of the primary node
node_netmask='$node_netmask'			# network mask for virtual IP
node_interface='$node_interface'			# interface name for virtual IP
other_node_name='$other_node_name'		# An arbitrary (but unique) string; Usually the hostname of the other node
other_node_id=$other_node_id				# A small integer;  Usually 1 or 2 
other_node_ip='$other_node_ip'		# The IP address of the other node in the cluster
EOT

cat $confloc

pghom=`echo ~postgres`
echo $pghom

cp ./HA2node.pl $pghom/HA2node.pl
chmod +x $pghom/HA2node.pl

cat <<EOT >> ./HA2postgres
# check postgres cluster and failover VIP
*   *   *   *   *   root   perl $pghom/HA2node.pl $confloc 
EOT

mv ./HA2postgres /etc/cron.d/
chcon -t system_cron_spool_t /etc/cron.d/HA2postgres

echo
echo "Successfully installed HA2node!"
