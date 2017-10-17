require 'spec_helper'

describe 'mirrors::debian', :type => :class do
    it do
        should contain_file('/srv/mirrors/debian').with({
            'ensure' => 'directory',
            'owner'  => 'mirror',
            'group'  => 'mirror',
            'mode'   => '0755',
        })
    end
    it do
        should contain_file('/etc/ftpsync').with({
            'ensure'  => 'present',
            'owner'   => 'mirror',
            'group'   => 'mirror',
            'mode'    => '0555',
        })
    end
    it do
        should contain_file('/var/log/ftpsync/').with({
            'ensure'  => 'directory',
            'owner'   => 'mirror',
            'group'   => 'mirror',
            'mode'    => '0755',
        })
    end
end
