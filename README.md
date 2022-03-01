# HA2node
A simple script that can be used with postgres and repmgr to create a simple two node HA solution. This script makes it possible to to auto assign a VIP address to the primary node, even after an automatic failover occurs, thus ensuring basic HA requirements.

# To install
sudo ./install.sh

You need run the install script on both nodes.
During the installation you need to configure the following parameters:
node_vip            # The virtual IP of the primary node (used to connect to postgres database)

node_netmask        # network mask for virtual IP

node_interface      # interface name for virtual IP

other_node_name     # This is the node_name parameter of the other node, you can check it on the other node in repmgr.conf

other_node_id       # This is the node_id parameter of the other node, you can check it on the other node in repmgr.conf

other_node_ip       # The IP address of the other node


After the installation you can configure your application to connect to the database via the VIP address.
