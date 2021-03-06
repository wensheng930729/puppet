# web server hosting https://docs.wikimedia.org
class profile::doc {

    require_package(['php-fpm', 'php-xml'])

    class { '::httpd':
        modules => ['headers',
                    'rewrite',
                    'proxy',
                    'proxy_fcgi'],
    }

    class { '::httpd::mpm':
        mpm    => 'worker',
        source => 'puppet:///modules/profile/doc/httpd_worker.conf'
    }

    # Apache configuration for doc.wikimedia.org
    httpd::site { 'doc.wikimedia.org':
        content => template('profile/doc/httpd-doc.wikimedia.org.erb'),
    }

    git::clone { 'integration/docroot':
        directory => '/srv/docroot',
        owner     => 'nobody',
        group     => 'wikidev',
        shared    => true,
    }

    ferm::service { 'doc-http':
        proto  => 'tcp',
        port   => '80',
        srange => '($CACHES $DEPLOYMENT_HOSTS)',
    }

    user { 'doc-uploader':
        ensure => present,
        shell  => '/bin/false',
        system => true,
    }
    file { '/srv/docroot/org/wikimedia/doc':
        ensure  => 'directory',
        owner   => 'doc-uploader',
        group   => 'wikidev',
        mode    => '0755',
        require => Git::Clone['integration/docroot'],
    }

    class {'::deployment::umask_wikidev': }

    backup::set { 'srv-docroot-org-wikimedia-doc': }

    class { '::rsync::server': }

    rsync::server::module { 'doc':
        ensure         => present,
        comment        => 'Docroot of https://doc.wikimedia.org/',
        read_only      => 'no',
        path           => '/srv/docroot/org/wikimedia/doc',
        uid            => 'doc-uploader',
        gid            => 'wikidev',
        hosts_allow    => ['contint1001.wikimedia.org', 'contint2001.wikimedia.org'],
        auto_ferm      => true,
        auto_ferm_ipv6 => true,
        require        => [
            User['doc-uploader'],
            File['/srv/docroot/org/wikimedia/doc'],
        ],
    }

    base::service_auto_restart { 'rsync': }
}
