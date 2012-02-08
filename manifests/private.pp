class openssl::private {
  # The main filter resource: scrubs user input, sets several variables for
  # later use lower in the stack and acts as a generic, private API to the outer
  # resources.
  #
  # Called By:
  #  * openssl::certmaster
  #  * openssl::server
  #  * openssl::client
  #
  # Parameters:
  #  *ensure* -- Sets the availability of all resources. (present|absent)
  #  *ca_name* -- Sets the CA's name, influencing exact FS position.
  #  *ca_host* -- Sets the client/server hostname for which to generate certificates.
  #  *type* -- Sets the distinction between client/server generation.
  #
  define main($ensure, $ca_name, $ca_host, $type) {
    case $type {
      certmaster, server, client: {
        case $ensure {
          present, absent: {

            $rootdir = "${openssl::vardir}/${ca_name}"
            $ssldir = "${rootdir}/ssl"
            $cadir = "${ssldir}/ca"
            $serverdir = "${ssldir}/servers"
            $clientsdir = "${ssldir}/clients"

            case $type {
              certmaster: {
                class { openssl::private::master:
                  ensure => $ensure,
                  ca_name => $ca_name,
                }
              }
              client, server: {
                # The virtual resource is realized in openssl::private::master
                # and generates the signed certificates for the given clients.
                @openssl::private::keymaster::client { "${type}_${ca_host}":
                  ensure => $ensure,
                  ca_host => $ca_host,
                  ca_name => $ca_name,
                  type => $type,
                }

                # The concrete resource, copies signed certificates from the
                # central authority to the local client machine. If the
                # certificates are _not_ available file(/dev/null) is used. See
                # notes below; search for '/dev/null'
                openssl::private::client { "${type}_${ca_host}":
                  ensure => $ensure,
                  ca_host => $ca_host,
                  ca_name => $ca_name,
                  type => $type,
                }

              }
              default: { fail "type parameter must be (certmaster|server|client) not ${type}" }
            }
          }
          default: { fail 'ensure parameter must be (present|absent)' }
        } # Oh god, the close bracket wastelands!
      }
      default: { fail 'type parameter must be (certmaster|server|client)' }
    }
  }

  # Creates all central authority certificates in their proper heirarchy,
  # realizing client/server certificates as well.
  #
  # Parameters
  #  *ensure* -- Sets the availability of _all_ certificates for the given ca_name.
  #  *ca_name* -- Sets the CA name, influencing heirarchy and certificate contents.
  class master($ensure, $ca_name) {
    # See the O'Reilly SSL text for more details, especially chapter four.
    file {
      "${cadir}/index.txt":
        require => File["${cadir}"],
        ensure => $ensure;
      "${cadir}/openssl.cnf":
        ensure => $ensure ? {
          present => file,
          default => $ensure,
        },
        require => File["${cadir}/index.txt"],
        source => 'puppet:///openssl/openssl.cnf';
    }

    Exec { cwd => $cadir, }
    exec {
      "${ca_name} serial index":
        command => "echo '01' > ${cadir}/serial",
        require => File["${cadir}/openssl.cnf"],
        creates => "${cadir}/serial";
      "${ca_name} cacert.pem":
        command => "openssl req -x509 -config openssl.cnf -newkey rsa:2048 -days 365 -out cacert.pem -outform PEM -subj /CN=${ca_name}CA/ -nodes",
        require => Exec["${ca_name} serial index"],
        creates => "${cadir}/cacert.pem";
      "${ca_name} cacert.cer":
        command => "openssl x509 -in cacert.pem -out cacert.cer -outform DER",
        require => Exec["${ca_name} cacert.pem"],
        creates => "${cadir}/cacert.cer";
    }

    Openssl::Private::Keymaster::Client <| |>
  }

  # Copies signed certificates from the central authority to local system.
  #
  # Parameters
  #   *ensure* -- Sets the availability of _all_ certificates for the given ca_name.
  #   *ca_name* -- Sets the CA name, influencing heirarchy and certificate contents.
  #   *ca_host* -- Set the hostname for which to generate keys.
  #  [*type*] -- Set the distinction between server and client actions.
  define client($ensure, $ca_name, $ca_host, $type=client) {
    ## Definitions: src on keymaster, tgt on client
    $ssldir_src = "${openssl::vardir}/${ca_name}/ssl"
    $ssldir_tgt = "/etc/${ca_name}/ssl/${type}"

    $cacert_src = "${ssldir_src}/ca/cacert.pem"
    $cacert_tgt = "${ssldir_tgt}/cacert.pem"
    $key_src    = "${ssldir_src}/clients/${hostname}/key.pem"
    $key_tgt    = "${ssldir_tgt}/key.pem"
    $cert_src   = "${ssldir_src}/clients/${hostname}/cert.pem"
    $cert_tgt   = "${ssldir_tgt}/cert.pem"

    if $hostname == $ca_host {
      # The /ect/${ca_name}/ssl tree is common to both manners of
      # non-CA. However, puppet's (rightful) fixation of defining things only
      # once mean that there's a nasty alias problem here: whoops. For now, the
      # solution is simply to create client keys (and the root) first, meaning
      # that all servers _must_ be their own clients.
      case $type {
        server : {
          file { "$cacert_tgt":
            content => file($cacert_src),
            require => File[$ssldir_tgt],
            ensure => $ensure;
          }
        }
        client : {
          file {
            "/etc/${ca_name}":
              ensure => directory;
            "/etc/${ca_name}/ssl":
              require => File["/etc/${ca_name}"],
              ensure => directory;
          }
        }
      }
      file {
        "/etc/${ca_name}/ssl/${type}":
          require => File["/etc/${ca_name}/ssl"],
          ensure => directory;
        ## /dev/null is used here when we boot-strap the keymaster for the first
        ## time: as it acts as both keymaster and client there's a race
        ## condition between the realization of
        ## Openssl::Private::Keymaster::Client and Openssl::Private::Client; the
        ## former _must_ be run the keymaster client. However, none of the usual
        ## resource chaining suspects effect the delay needed. (To see it in
        ## action, run on a fresh keymaster box and remove /dev/null.
        ##
        ## As a side-effect, puppet agent will need to be invoked twice on the
        ## keymaster box, the first time to build its keys, the second to
        ## actually place them. Patches eagerly applied that change this.
        "$key_tgt":
          content => file($key_src, "/dev/null"),
          require => File[$ssldir_tgt],
          ensure => $ensure;
        "$cert_tgt":
          content => file($cert_src, "/dev/null"),
          require => File[$ssldir_tgt],
          ensure => $ensure;
      }
    }
  }

}
