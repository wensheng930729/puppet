class profile::dumps::generation::worker::cronrunner(
    $php = hiera('profile::dumps::generation_worker_cron_php'),
) {
    class { '::snapshot::cron':
        miscdumpsuser => 'dumpsgen',
        group         => 'www-data',
        filesonly     => false,
        php           => $php,
    }
}
