class base::standard_packages {

    if os_version('ubuntu >= trusty') {
        package { [ "linux-tools-${::kernelrelease}", 'linux-tools-generic' ]:
            ensure => present,
        }
    }

    require_package ([
        'acct',
        'apt-transport-https',
        'curl',
        'debian-goodies',
        'dnsutils',
        'dstat',
        'ethtool',
        'gdb',
        'gdisk',
        'git-fat',
        'git',
        'htop',
        'httpry',
        'iotop',
        'iperf',
        'jq',
        'libtemplate-perl', # Suggested by vim-scripts
        'lldpd',
        'lshw',
        'molly-guard',
        'moreutils',
        'numactl',
        'ncdu',
        'ngrep',
        'pigz',
        'psmisc',
        'pv',
        'python3',
        'quickstack',
        'screen',
        'strace',
        'sysstat',
        'tcpdump',
        'tmux',
        'tree',
        'vim',
        'vim-addon-manager',
        'vim-scripts',
        'wipe',
        'xfsprogs',
        'zsh',
    ])

    package { 'tzdata': ensure => latest }

    # pxz was removed in buster. In xz >= 5.2 (so stretch and later), xz has
    # builtin threading support using the -T option, so pxz was removed
    if os_version('debian <= stretch') {
        require_package('pxz')
    }

    # ack-grep was renamed to ack
    if os_version('debian >= stretch') {
        require_package('ack')
    } else {
        require_package('ack-grep')
    }

    # uninstall these packages
    package { [
            'apport',
            'apt-listchanges',
            'command-not-found',
            'command-not-found-data',
            'ecryptfs-utils',
            'mlocate',
            'os-prober',
            'python3-apport',
            'wpasupplicant',
        ]:
        ensure => absent,
    }

    # purge these packages
    package { [
            'atop', # atop causes severe performance degradation T192551 debian:896767
        ]:
        ensure => purged,
    }

    # Installed by default on Ubuntu, but not used (and it's setuid root, so
    # a potential security risk).
    #
    # Limited to Ubuntu, since Debian doesn't pull it in by default
    if os_version('ubuntu >= trusty') {
        package { 'ntfs-3g': ensure => absent }
    }

    # Can be dropped once trusty/jessie are gone, not installed by default in stretch onwards
    package { 'at': ensure => purged }

    # On Ubuntu, eject is installed via the ubuntu-minimal package
    # Uninstall in on Debian since it ships a setuid helper and we don't
    # have servers with installed optical drives
    if os_version('debian >= jessie') {
        package { 'eject': ensure => absent }
    }

    # real-hardware specific
    if $facts['is_virtual'] == false {
        # As of September 2015, mcelog still does not support newer AMD processors.
        # See <https://www.mcelog.org/faq.html#18>.
        if $::processor0 !~ /AMD/ {
          if os_version('debian == jessie') or os_version('debian == stretch') {
              require_package('mcelog')
              base::service_auto_restart { 'mcelog': }
          }
          require_package('intel-microcode')
        }
        # It should be possible to run mcelog and rasdaemon in parallel
        # however we should first gain operational experience
        if $::lsbdistcodename == 'buster' or hiera('install_rasdaemon', false) {  # lint:ignore:wmf_styleguide
            require_package('rasdaemon')
            base::service_auto_restart { 'rasdaemon': }
        }
        # If we once used the hiera override to install rasdaemon on a stretch host,
        # and then we remove the hiera override, we should purge the package and service.
        # Package doesn't exist in jessie, so don't have to worry about that.
        # TODO: remove this (and the hiera overrides) after we've finished evaluating rasdaemon
        # or have completed the move to buster; see also T205396
        elsif $::lsbdistcodename == 'stretch' and !hiera('install_rasdaemon', false) {  # lint:ignore:wmf_styleguide
            package { 'rasdaemon': ensure => purged }
            base::service_auto_restart { 'rasdaemon': ensure => absent }
        }
    }

    # for HP servers only - install the backplane health service and CLI
    # As of February 2018, we are using a version of Facter where manufacturer
    # is a current fact.  In a future upgrade, it will be a legacy fact and
    # should be replaced with a parse of the dmi fact (which will be a map not
    # a string).
    if $facts['is_virtual'] == false and $facts['manufacturer'] == 'HP' {
        require_package('hp-health')
    }

    # Pulled in via tshark below, defaults to "no"
    debconf::seen { 'wireshark-common/install-setuid': }
    package { 'tshark': ensure => present }

    # An upgrade from jessie to stretch leaves some old binary
    # packages around, remove those
    if os_version('debian == stretch') {
        package { [
                  'libapt-inst1.5',
                  'libapt-pkg4.12',
                  'libdns-export100',
                  'libirs-export91',
                  'libisc-export95',
                  'libisccfg-export90',
                  'liblwres90',
                  'libgnutls-deb0-28',
                  'libhogweed2',
                  'libjasper1',
                  'libnettle4',
                  'libruby2.1',
                  'ruby2.1',
                  'libpsl0',
                  'libwiretap4',
                  'libwsutil4',
                  'libbind9-90',
                  'libdns100',
                  'libisc95',
                  'libisccc90',
                  'libisccfg90',
                  'python-reportbug',
                  'libpng12-0'
            ]:
            ensure => absent,
        }
    }

    # An upgrade from stretch to buster leaves some old binary packages around, remove those
    if os_version('debian == buster') {
        package {['libbind9-140', 'libdns162', 'libevent-2.0-5', 'libisc160',
                  'libisccc140', 'libisccfg140', 'liblwres141', 'libonig4',
                  'libperl5.24', 'ruby2.3', 'libruby2.3', 'libunbound2']:
            ensure => absent,
        }

        # mcelog is broken with the Linux kernel used in buster
        package {['mcelog']:
            ensure => purged,
        }
    }

    if os_version('debian >= jessie') {
        base::service_auto_restart { 'lldpd': }
        base::service_auto_restart { 'cron': }
    }

    # Safe restarts are supported since systemd 219:
    # * systemd now provides a way to store file descriptors
    # per-service in PID 1. This is useful for daemons to ensure
    # that fds they require are not lost during a daemon
    # restart. The fds are passed to the daemon on the next
    # invocation in the same way socket activation fds are
    # passed. This is now used by journald to ensure that the
    # various sockets connected to all the system's stdout/stderr
    # are not lost when journald is restarted.
    if os_version('debian >= stretch') {
        base::service_auto_restart { 'systemd-journald': }
    }
}
