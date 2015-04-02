# Puppet manifest for managed nodes:

node 'default' {
  notify { "INFO: puppet-01 applying default node settings for client ${::fqdn}": }
}

node 'puppet-01.blah.internal' {
  include ntp

  include apache
  include apache::default_mods
  include apache::mod::wsgi

  class { 'apache::mod::passenger':
    passenger_root               => "/usr/lib/ruby/gems/1.8/gems/passenger-3.0.21",
    passenger_ruby               => "/usr/bin/ruby",
    passenger_high_performance   => "on",
    passenger_max_pool_size      => "12",
    passenger_pool_idle_time     => "1500",
    passenger_stat_throttle_rate => "120",
    rack_autodetect              => "off",
    rails_autodetect             => "off",
  }

  class {'apache::mod::ssl':
    ssl_cipher => 'AES128+EECDH:AES128+EDH:AES256+EECDH:AES256+EDH:HIGH:3DES:!PSK:!MD5:!aNULL:!eNULL',
  }

  apache::vhost { "${::fqdn}":
    ensure               => present,
    default_vhost        => false,
    port                 => '8140',
    docroot              => '/usr/share/puppet/rack/puppetmasterd/public',
    rack_base_uris       => [ '/' ],
    directories          => [{ 'path' => '/usr/share/puppet/rack/puppetmasterd/', 'provider' => 'directory', 'options' => 'None', 'allow' => 'from All' }],
    ssl                  => true,
    access_log_file      => "puppetmaster.ssl_access.log",
    error_log_file       => "puppetmaster.ssl_error.log",
    ssl_certs_dir        => '/var/lib/puppet/ssl/certs',
    ssl_ca               => '/var/lib/puppet/ssl/ca/ca_crt.pem',
    ssl_cert             => '/var/lib/puppet/ssl/certs/puppet-01.blah.internal.pem',
    ssl_crl              => '/var/lib/puppet/ssl/ca/ca_crl.pem',
    ssl_key              => '/var/lib/puppet/ssl/private_keys/puppet-01.blah.internal.pem',
    ssl_chain            => '/var/lib/puppet/ssl/ca/ca_crt.pem',
    ssl_options          => [ '+StdEnvVars', '+ExportCertData' ],
    ssl_cipher           => 'AES128+EECDH:AES128+EDH:AES256+EECDH:AES256+EDH:HIGH:3DES:!PSK:!MD5:!aNULL:!eNULL',
    ssl_honorcipherorder => 'on',
    ssl_verify_client    => 'optional',
    ssl_verify_depth     => 1,
    request_headers      => [ 'unset X-Forwarded-For', 'set X-SSL-Subject %{SSL_CLIENT_S_DN}e', 'set X-Client-DN %{SSL_CLIENT_S_DN}e', 'set X-Client-Verify %{
    log_level            => warn,
  }
}
