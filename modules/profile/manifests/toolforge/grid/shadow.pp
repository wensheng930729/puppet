# This profile sets up a grid shadow master in the Toolforge model.

class profile::toolforge::grid::shadow(
    $gridmaster = hiera('sonofgridengine::gridmaster'),
){
    include profile::openstack::main::clientpackages
    include profile::openstack::main::observerenv
    include profile::toolforge::infrastructure

    class { '::sonofgridengine::shadow_master':
        gridmaster => $gridmaster,
        sgeroot    => $profile::toolforge::grid::base::geconf,
    }
}
