# A cheap Puppet CA using OpenSSL.

This module provides several resources that will act as a quick-and-dirty CA:
don't serve certificates over the public Internet, but do use these certificates
to provide two-way signing between otherwise isolated client/server systems.

## Quick Start

Consider a very peculiar network in which there exist only the central puppet
master, `puppet`, our git daemon, slug compiler box `git` and the message bus
machine `mq0`. Here's how you'd declare `puppet` to be the central authority for
all certificates, `mq0` to require server keys and all other hosts client keys.

    include openssl

    if $hostname == 'puppet' {
      # Declare 'puppet' to be the central authority; all certificates will be
      # created and signed here.
      class { 'openssl::certmaster':
        ca_name => 'rabbitmq',
        ensure => present,
      }
    }

    # Provide all RabbitMQ machines with the certificates they need to serve
    # up encrypted connections.
    Openssl::Server {
      ca_name => 'rabbitmq',
    }
    openssl::server {
      'mq0' : ensure => present;
    }

    # Copy client keys from central authority to all client boxes.
    Openssl::Client {
      ca_name => 'rabbitmq',
    }
    openssl::client {
      'puppet': ensure => present;
      'git'   : ensure => present;
      'mq0'   : ensure => present;
    }

Bootstrapping the certificate authority will take two runs of `puppet agent`,
owing to the way in which client/server certificates are distributed in the
absence of their being stored in the 'CA' directory structure.

## Diving into the source

You'll need to be familiar with:

 * [openssl](http://shop.oreilly.com/product/9780596002701.do)
 * [defined resources](http://docs.puppetlabs.com/guides/language_guide.html#resource-collections)
 * [virtual resources](http://docs.puppetlabs.com/guides/virtual_resources.html)

I've attempted to document the module source well, but please take out an issue
if something could be more clear.
