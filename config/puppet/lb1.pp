node lb1 {

  # Install the software we need:
  # ipvsadm: loadbalancer
  # keepalived: manages ip's and lb definitions
  # iptables: to set SNAT rules in postrouting
  $packages = ['keepalived', 'ipvsadm', 'iptables']

  package { $packages:
    ensure  => installed,
    notify  => File["/etc/keepalived/keepalived.conf"],
  }

  # create a directory for all the config files
  file { "/etc/myconf":
    ensure  => directory,
    owner   => "root",
    group   => "root",
    mode    => "0755",
  }

  # the keepalived config will be stored in /etc/myconf
  file { "/etc/keepalived/keepalived.conf":
    ensure  => link,
    target  => "/etc/myconf/keepalived.conf",
    owner   => "root",
    group   => "root",
    require => File["/etc/myconf"],
  }

  # set up some kernel settings for lvs
  # ip forwarding
  augeas { "sysctl_conf/net.ipv4.ip_forward":
    context => "/files/etc/sysctl.conf",
    onlyif  => "get net.ipv4.ip_forward != '1'",
    changes => "set net.ipv4.ip_forward '1'",
    notify  => Exec["sysctl"],
  }
  augeas { "sysctl_conf/net.ipv4.vs.conntrack":
    context => "/files/etc/sysctl.conf",
    onlyif  => "get net.ipv4.vs.conntrack != '1'",
    changes => "set net.ipv4.vs.conntrack '1'",
    notify  => Exec["sysctl"],
  }
  exec { "/sbin/sysctl -p":
    alias => "sysctl",
    refreshonly => true,
    require => Augeas["sysctl_conf/net.ipv4.ip_forward", "sysctl_conf/net.ipv4.vs.conntrack"]
  }

  augeas{ "network_interface" :
    context => "/files/etc/network/interfaces",
    changes => [
      "set auto[child::1 = 'eth1']/1 eth1",
      "set iface[. = 'eth1'] eth1",
      "set iface[. = 'eth1']/family inet",
      "set iface[. = 'eth1']/method static",
      "set iface[. = 'eth1']/address 192.168.200.10",
      "set iface[. = 'eth1']/netmask 255.255.255.0",
      # "set iface[. = 'eth1']/network 192.168.200.0",
      # "set iface[. = 'eth1']/gateway 192.168.200.1",
      "set iface[. = 'eth1']/pre-up 'iptables-restore < /etc/myconf/iptables.rules'",
      "set iface[. = 'eth1']/post-down 'iptables-restore < /etc/iptables.downrules'",
      "set auto[child::1 = 'eth2']/1 eth2",
      "set iface[. = 'eth2'] eth2",
      "set iface[. = 'eth2']/family inet",
      "set iface[. = 'eth2']/method static",
      "set iface[. = 'eth2']/address 192.168.201.10",
      "set iface[. = 'eth2']/netmask 255.255.255.0",
      # "set iface[. = 'eth2']/network 192.168.201.0",
      # "set iface[. = 'eth2']/gateway 192.168.201.1",
    ],
    require => File["/etc/myconf"],
  }

  exec { "iptables":
    command => "/sbin/iptables -t nat -A POSTROUTING -m ipvs --vaddr 192.168.200.20/32 --vport 80 -j SNAT --to-source 192.168.201.10",
  }

  service { "keepalived":
    ensure      => running,
    name        => "keepalived",
    hasstatus   => false,
    hasrestart  => true,
    enable      => true,
    require     => File["/etc/keepalived/keepalived.conf"],
  }

}