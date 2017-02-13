require 'spec_helper'

describe 'gnocchi::db::postgresql' do

  shared_examples_for 'gnocchi::db::postgresql' do
    let :req_params do
      { :password => 'pw' }
    end

    let :pre_condition do
      'include postgresql::server'
    end

    context 'with only required parameters' do
      let :params do
        req_params
      end

      it { is_expected.to contain_postgresql__server__db('gnocchi').with(
        :user     => 'gnocchi',
        :password => 'md590440288cb225f56d585b88ad270cd37'
      )}
    end
  end

  on_supported_os({
    :supported_os   => OSDefaults.get_supported_os
  }).each do |os,facts|
    context "on #{os}" do
      let (:facts) do
        facts.merge!(OSDefaults.get_facts({ :concat_basedir => '/var/lib/puppet/concat' }))
      end

      it_configures 'gnocchi::db::postgresql'
    end
  end
end
