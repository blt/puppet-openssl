class openssl::private::keymaster {
  # Generate the central authority's disk heirarchy.
  #
  define catree($ensure=present) {
    $ca_name = $title
    $rootdir = "${openssl::vardir}/${ca_name}"
    $ssldir = "${rootdir}/ssl"
    $cadir = "${ssldir}/ca"
    $serverdir = "${ssldir}/servers"
    $clientsdir = "${ssldir}/clients"

    case $ensure {
      present : {
        file {
          "$rootdir":
            path => $rootdir,
            ensure => directory;
          "$ssldir":
            path => $ssldir,
            require => File[$rootdir],
            ensure => directory;
          "$cadir":
            path => $cadir,
            require => File[$ssldir],
            ensure => directory;
          "$cadir/certs":
            path => "$cadir/certs",
            require => File[$cadir],
            ensure => directory;
          "$cadir/private":
            path => "$cadir/private",
            mode => 0700,
            require => File[$cadir],
            ensure => directory;
          "$clientsdir":
            path => $clientsdir,
            require => File[$rootdir],
            ensure => directory;
          "$serverdir":
            path => $serverdir,
            require => File[$rootdir],
            ensure => directory;
        }
      }
      absent: {
        file { "${rootdir}":
          ensure => absent,
          force => true,
        }
      }
      default: {
        fail "parameter must be (present|absent) not ${ensure}"
      }
    }
  }

  # Generates all client signed certificates.
  #
  define client($ensure, $ca_name, $ca_host, $type=client) {
    $filldir = $type ? {
      server => "${serverdir}/${ca_host}",
      client => "${clientsdir}/${ca_host}",
      default => fail( 'type parameter must be (server|client)' )
    }

    $cadir = "${openssl::vardir}/${ca_name}/ssl/ca"
    $key_pem = "${filldir}/key.pem"
    $req_pem = "${filldir}/req.pem"
    $cert_pem = "${filldir}/cert.pem"

    file {
      $filldir:  ensure => directory;
      $key_pem:  ensure => $ensure;
      $req_pem:  ensure => $ensure;
      $cert_pem: ensure => $ensure;
    }
    Exec { cwd => $filldir, }
    exec {
      "$type $ca_host key.pem":
        command => "openssl genrsa -out key.pem 2048",
        require => File[$filldir],
        before  => File[$key_pem],
        creates => $key_pem;
      "$type $ca_host csr":
        command => "openssl req -new -key key.pem -out req.pem -outform PEM -subj /CN=${ca_host}/O=${type}/ -nodes",
        require => Exec["client $ca_host key.pem"],
        before  => File[$req_pem],
        creates => $req_pem;
      "$type $ca_host cert.pem":
        cwd => $cadir,
        command => "openssl ca -config openssl.cnf -in ${filldir}/req.pem -out ${filldir}/cert.pem -notext -batch -extensions server_ca_extensions",
        require => Exec["$type $ca_host csr", "${ca_name} cacert.cer"],
        before  => File[$cert_pem],
        creates => $cert_pem;
    }

  }

}
