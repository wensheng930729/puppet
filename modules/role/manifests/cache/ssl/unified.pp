class role::cache::ssl::unified(
    $labs_server_name = 'beta.wmflabs.org',
    $labs_subjects = ['beta.wmflabs.org'],
) {
    if ( $::realm == 'production' ) {
        monitoring::service { 'https':
            description   => 'HTTPS',
            check_command => 'check_sslxNN',
        }

        tlsproxy::localssl { 'unified':
            server_name    => 'www.wikimedia.org',
            certs          => ['ecc-uni.wikimedia.org', 'uni.wikimedia.org'],
            default_server => true,
            do_ocsp        => true,
            upstream_ports => [3120, 3121, 3122, 3123, 3124, 3125, 3126, 3127],
            redir_port     => 8080,
        }
    }
    else {
        tlsproxy::localssl { 'unified':
            server_name    => $labs_server_name,
            acme_subjects  => $labs_subjects,
            default_server => true,
            do_ocsp        => false,
            skip_private   => true,
            upstream_ports => [3120, 3121, 3122, 3123, 3124, 3125, 3126, 3127],
            redir_port     => 8080,
        }
    }

    # ordering ensures nginx/varnish config/service-start are
    #  not intermingled during initial install where they could
    #  have temporary conflicts on binding port 80
    Service['nginx'] -> Service<| tag == 'varnish_instance' |>
}
