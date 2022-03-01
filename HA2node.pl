#!/usr/bin/perl

use strict;
use 5.010;
use Data::Dumper qw(Dumper);
use Cwd 'getcwd';
use POSIX 'strftime';
use Carp;

my $scriptPath = getcwd();
my $scriptName = $0; $scriptName =~ s/\.\///;

sub  trim { my $s = shift; chomp $s; $s =~ s/^\s+|\s+$//g; return $s };

sub source {
    my $file = shift;
    open my $fh, "<", $file
        or croak "could not open $file: $!";

    while (<$fh>) {
        chomp;
        next unless my ($var, $value) = /\s*(\w+)=([^#]+)/;
        $ENV{$var} = $value;
    }
}

source $ARGV[0];
#source "/etc/repmgr/13/repmgr.conf";
#source "$ENV{REPMGRCONF}";

my $conninfo = $ENV{conninfo}; $conninfo  =~ s/\'//g;
my $node_name = $ENV{node_name}; $node_name  =~ s/\'//g; $node_name=trim($node_name);
my $node_id = $ENV{node_id}; $node_id  =~ s/\'//g; $node_id=trim($node_id);
my $node_log = $ENV{log_file}; $node_log =~ s/\'//g; $node_log=trim($node_log);

my $node_vip = $ENV{node_vip}; $node_vip  =~ s/\'//g; $node_vip=trim($node_vip);
my $node_interface = $ENV{node_interface}; $node_interface  =~ s/\'//g; $node_interface=trim($node_interface);
my $node_netmask = $ENV{node_netmask}; $node_netmask  =~ s/\'//g; $node_netmask=trim($node_netmask);
my $node_vip_netmasked = $node_vip . $node_netmask;
my $other_node_name = $ENV{other_node_name}; $other_node_name  =~ s/\'//g; $other_node_name=trim($other_node_name);
my $other_node_id = $ENV{other_node_id}; $other_node_id  =~ s/\'//g; $other_node_id=trim($other_node_id);
my $other_node_ip = $ENV{other_node_ip}; $other_node_ip  =~ s/\'//g; $other_node_ip=trim($other_node_ip);

my $node_ip = '0.0.0.0';
my $ips='';
#my $other_node_name = "server2";
#my $other_node_id = 2;
#my $other_node_ip = "192.168.10.182";

if($conninfo =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/)
{
    $node_ip = $1;
}

sub logMessage {
  my $param = shift;
  my $currentDate = strftime "%Y.%m.%d %H:%M:%S", localtime time;
  print "[$currentDate] $param \n";
  `echo "[$currentDate] $param" >> /var/log/repmgr/repmgrd.log`;
}

##################################################
# HA STANDBY-RA KELL VALTANOM FAIL MIATT
##################################################
my $result=`su -c '/usr/pgsql-13/bin/repmgr -f /etc/repmgr/13/repmgr.conf cluster show 2>&1' postgres`;
if ($result =~ /node \"$other_node_name\" \(ID\: $other_node_id\) is registered as standby but running as primary/){

   $result=`systemctl stop postgresql-13.service`;
   if ($result!=0){
     logMessage( "[ERROR] failed to stop postgresql service!" );
   }
   else {
     logMessage( "[NOTICE] Succesfully stopped postgresql service!" );
   }

   $result=`su -c "/usr/pgsql-13/bin/repmgr node rejoin -d 'host=$other_node_ip user=repmgr dbname=repmgr connect_timeout=2' --force-rewind" postgres`;
   if ($result!=0){
     logMessage( "[ERROR] failed to rejoin as standby!" );
   }
   else {
     logMessage( "[NOTICE] Succesfully rejoined cluster as standby!" );
   }

   $ips=`/sbin/ip a s $node_interface | egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2`;
   if ($ips =~ /$node_vip/){
      logMessage( "[NOTICE] VIP address $node_vip is available on $node_interface interface, removing now" );
      my $res = `/sbin/ip addr del $node_vip_netmasked dev $node_interface`;
      if ($res!=0){
         logMessage( "[ERROR] failed to remove VIP from interface!" );
      }
      else {
         logMessage( "[NOTICE] succesfully removed VIP $node_vip from $node_interface interface" );
      }
   }
   exit 0;
}


##################################################
# HA NINCS VIP, VAGY VAN DE NEM KELLENE
##################################################
my $timetocheck = strftime "%Y.%m.%d %H:%M:", localtime(time-60);
$result = `tail /var/log/repmgr/repmgrd.log | grep "$timetocheck"`;
if ($result =~ /monitoring primary node \"$node_name\"/) {
   $ips=`/sbin/ip a s $node_interface | egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2`;
   if ($ips =~ /$node_vip/){
      say "ALL is good, the VIP is ON, nothing to do!";
   }
   else {
      logMessage( "[NOTICE] Adding VIP address $node_vip to $node_interface interface" );
      my $res = `/sbin/ip addr add $node_vip_netmasked dev $node_interface`;
      if ($res!=0){
         logMessage( "[ERROR] failed to add VIP to interface!" );
      }
      else {
         logMessage( "[NOTICE] succesfully added VIP $node_vip to $node_interface interface" );
      }
   }
}
elsif ($result =~ /node \"$node_name\" \(ID\: $node_id\) monitoring upstream node/){
   $ips=`/sbin/ip a s $node_interface | egrep -o 'inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d' ' -f2`;
   if ($ips =~ /$node_vip/){
      logMessage( "[NOTICE] VIP address $node_vip is available on $node_interface interface, removing now" );
      my $res = `/sbin/ip addr del $node_vip_netmasked dev $node_interface`;
      if ($res!=0){
         logMessage( "[ERROR] failed to remove VIP from interface!" );
      }
      else {
         logMessage( "[NOTICE] succesfully removed VIP $node_vip from $node_interface interface" );
      }
   }
}
else{
   say "ERROR, can't identify node type";
}
