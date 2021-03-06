#    Copyright 2015 Mirantis, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

class contrail::control {

# Resources defaults
  Package { ensure => present }

  File {
    ensure  => present,
    mode    => '0644',
    owner   => 'contrail',
    group   => 'contrail',
    require => Package['contrail-openstack-control'],
  }

  Exec {
    provider => 'shell',
    path     => '/usr/bin:/bin:/sbin',
  }

# Packages
  package { 'contrail-dns': }
  package { 'contrail-control': } ->
  package { 'contrail-openstack-control': }

# Contrail control config files
  file { '/etc/contrail/vnc_api_lib.ini':
    content => template('contrail/vnc_api_lib.ini.erb')
  }

  file { '/etc/contrail/contrail-control.conf':
    content => template('contrail/contrail-control.conf.erb'),
  }

  file { '/etc/contrail/contrail-dns.conf':
    content => template('contrail/contrail-dns.conf.erb'),
    require => Package['contrail-dns'],
  }

  file { '/etc/contrail/dns/contrail-named.conf':
    content => template('contrail/contrail-named.conf.erb'),
    require => Package['contrail-dns'],
  }

  file { '/etc/contrail/dns/contrail-rndc.conf':
    source  => 'puppet:///modules/contrail/contrail-rndc.conf',
    require => Package['contrail-dns'],
  }

  file { '/etc/contrail/contrail-control-nodemgr.conf':
    content => template('contrail/contrail-control-nodemgr.conf.erb'),
  }

# Control service
  service { 'contrail-named':
    ensure    => running,
    require   => Package['contrail-dns'],
    subscribe => [File['/etc/contrail/dns/contrail-named.conf'],
                  File['/etc/contrail/dns/contrail-rndc.conf'],
                  ]
  }
  service { 'supervisor-control':
    ensure    => running,
    enable    => true,
    require   => Package['contrail-openstack-control'],
    subscribe => [File['/etc/contrail/contrail-control.conf'],
                    File['/etc/contrail/contrail-dns.conf'],
                    ],
  }

  exec { 'prov_control_bgp':
    command => "python /opt/contrail/utils/provision_control.py \
--api_server_ip ${contrail::contrail_mgmt_vip} --api_server_port 8082 \
--oper add --host_name ${::fqdn} --host_ip ${contrail::address} --router_asn ${contrail::asnum} \
--admin_user neutron --admin_tenant_name services --admin_password ${contrail::service_token} \
&& touch /opt/contrail/prov_control_bgp-DONE",
    require => [Service['supervisor-control'],File['/etc/contrail/vnc_api_lib.ini']],
    creates => '/opt/contrail/prov_control_bgp-DONE',
  }

}
