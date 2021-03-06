#
# This class configures elasticsearch
#
# == Parameters:
#
# For documentation of parameters, see the elasticsearch profile.
#
# [*expose_http*]
#   For historical reason we expose HTTP endpoints. For new clusters, we want
#   to disable that, and cleanup the old ones. For transition, let's make this
#   configureable.
class profile::elasticsearch::cirrus(
    String $ferm_srange = hiera('profile::elasticsearch::cirrus::ferm_srange'),
    Boolean $expose_http = hiera('profile::elasticsearch::cirrus::expose_http'),
    String $storage_device = hiera('profile::elasticsearch::cirrus::storage_device'),
    Boolean $use_acme_chief = hiera('profile::elasticsearch::cirrus::use_acme_chief', false),
    Array[String] $prometheus_nodes = hiera('prometheus_nodes'),
    String $ocsp_proxy = hiera('http_proxy', ''),
) {
    include ::profile::elasticsearch

    package {'wmf-elasticsearch-search-plugins':
        ensure => present,
    }

    # Since the elasticsearch service is dynamically named after the cluster
    # name, and because there can be multiple elasticsearch services on the
    # same node we need to use collectors.
    Package['wmf-elasticsearch-search-plugins'] -> Service <| tag == 'elasticsearch_services' |>

    # Alternatively we could pass these again?
    # certificate_name and tls_port aren't even
    # elasticsearch::instance params,

    $::profile::elasticsearch::filtered_instances.each |$instance_title, $instance_params| {
        $cluster_name = $instance_params['cluster_name']
        $http_port = $instance_params['http_port']
        $tls_port = $instance_params['tls_port']

        if $expose_http {
            ferm::service { "elastic-http-${http_port}":
                proto   => 'tcp',
                port    => $http_port,
                notrack => true,
                srange  => $ferm_srange,
            }
        }

        ferm::service { "elastic-https-${tls_port}":
            proto  => 'tcp',
            port   => $tls_port,
            srange => $ferm_srange,
        }

        if !$use_acme_chief {
            elasticsearch::tlsproxy { $cluster_name:
                certificate_names => [$instance_params['certificate_name']],
                upstream_port     => $http_port,
                tls_port          => $tls_port,
                server_name       => $instance_params['certificate_name'],
                ocsp_proxy        => $ocsp_proxy,
            }
        } else {
            elasticsearch::tlsproxy { $cluster_name:
                upstream_port => $http_port,
                tls_port      => $tls_port,
                acme_chief    => true,
                acme_certname => $instance_params['certificate_name'],
                ocsp_proxy    => $ocsp_proxy,
            }
        }

        elasticsearch::log::hot_threads_cluster { $cluster_name:
            http_port => $http_port,
        }
    }

    udev::rule { 'elasticsearch-readahead':
        content => "SUBSYSTEM==\"block\", KERNEL==\"${storage_device}\", ACTION==\"add|change\", ATTR{bdi/read_ahead_kb}=\"128\"",
    }

    # Install prometheus data collection
    $::profile::elasticsearch::filtered_instances.reduce(9108) |$prometheus_port, $kv_pair| {
        $instance_params = $kv_pair[1]
        $http_port = $instance_params['http_port']

        profile::prometheus::elasticsearch_exporter { "${::hostname}:${http_port}":
            prometheus_nodes   => $prometheus_nodes,
            prometheus_port    => $prometheus_port,
            elasticsearch_port => $http_port,
        }
        profile::prometheus::wmf_elasticsearch_exporter { "${::hostname}:${http_port}":
            prometheus_nodes   => $prometheus_nodes,
            prometheus_port    => $prometheus_port + 1,
            elasticsearch_port => $http_port,
        }
        $prometheus_port + 2
    }
}
