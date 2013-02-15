package { "apache2":
  ensure => installed,
}

# exec { "rm /var/www/index.html":
#   command => "/bin/rm /var/www/index.html",
#   require => Package["apache2"],
# }

file { "/var/www/index.html":
  ensure  => file,
  content => "$hostname \n",
  # require => Exec["rm /var/www/index.html"],
  require => Package["apache2"],
}

file { "/var/www/status":
  ensure  => file,
  content => "OK\n",
  require => Package["apache2"],
}

service { "apache2":
  enable      => true,
  ensure      => running,
  hasrestart  => true,
  hasstatus   => true,
  require     => Package["apache2"],
}