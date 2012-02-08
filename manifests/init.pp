# Defines puppet controls to act as quick-and-dirty CA.
#
# The central authority will create a directory of all certificates in the
# /var/lib/ hierarchy. 'client' machines are those that receive only
# signed-certificates sufficient to authenticate against a 'server', which are
# the signed certificates and the CA's root certificate plus the signed
# certificates unique to the server. 'client' and 'server' certificates are
# stored in the /etc hierarchy.
#
class openssl {
  include openssl::package

  $vardir = '/var/lib'

  # Creates central authority hierarchy, realizing all server and client virtual
  # resources.
  #
  # Parameters
  #  [*ensure*] -- Sets or destroys all certificates (present|absent)
  #  *ca_name*  -- Provides the name for the CA to use.
  class certmaster($ensure='', $ca_name) {
    openssl::private::keymaster::catree { $ca_name: ensure => present, }
    openssl::private::main { "${title}_${ca_name}_certmaster":
      ensure => $ensure,
      ca_host => $title,
      ca_name => $ca_name,
      type => certmaster,
    }
  }

  # Copies server certificates from the central authority to local certificate
  # heirarchy.
  #
  # Parameters
  #  [*ensure*] -- Sets or destroys all certificates (present|absent)
  #  *ca_name*  -- Provides the name for the CA to use.
  define server($ensure='', $ca_name) {
    openssl::private::main { "${title}_${ca_name}_server" :
      ensure => $ensure,
      ca_host => $title,
      ca_name => $ca_name,
      type => server,
    }
  }

  # Copies client certificates from the central authority to local certificate
  # heirarchy.
  #
  # Parameters
  #  [*ensure*] -- Sets or destroys all certificates (present|absent)
  #  *ca_name*  -- Provides the name for the CA to use.
  define client($ensure='', $ca_name) {
    openssl::private::main { "${title}_${ca_name}_client" :
      ensure => $ensure,
      ca_host => $title,
      ca_name => $ca_name,
      type => client,
    }
  }

}

