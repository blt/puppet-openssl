class openssl::package {
  package { 'openssl':
    ensure => present,
  }
}
