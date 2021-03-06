require 'spec_helper'

describe 'cinder::backend::hp3par_iscsi' do
  let (:title) { 'hp3par_iscsi' }

  let :req_params do
    {
      :hp3par_api_url   => 'https://172.0.0.2:8080/api/v1',
      :hp3par_username  => '3paradm',
      :hp3par_password  => 'password',
      :hp3par_iscsi_ips => '172.0.0.3',
      :san_ip            => '172.0.0.2',
      :san_login         => '3paradm',
      :san_password      => 'password',
    }
  end

  let :params do
    req_params
  end

  describe 'hp3par_iscsi volume driver' do
    it 'configure hp3par_iscsi volume driver' do
      is_expected.to contain_cinder_config('hp3par_iscsi/volume_driver').with_value('cinder.volume.drivers.san.hp.hp_3par_iscsi.HP3PARISCSIDriver')
      is_expected.to contain_cinder_config('hp3par_iscsi/hpe3par_api_url').with_value('https://172.0.0.2:8080/api/v1')
      is_expected.to contain_cinder_config('hp3par_iscsi/hpe3par_username').with_value('3paradm')
      is_expected.to contain_cinder_config('hp3par_iscsi/hpe3par_password').with_value('password')
      is_expected.to contain_cinder_config('hp3par_iscsi/hpe3par_iscsi_ips').with_value('172.0.0.3')
      is_expected.to contain_cinder_config('hp3par_iscsi/san_ip').with_value('172.0.0.2')
      is_expected.to contain_cinder_config('hp3par_iscsi/san_login').with_value('3paradm')
      is_expected.to contain_cinder_config('hp3par_iscsi/san_password').with_value('password')
    end
  end

  describe 'hp3par_iscsi backend with additional configuration' do
    before :each do
      params.merge!({:extra_options => {'hpe3par_iscsi/param1' => {'value' => 'value1'}}})
    end

    it 'configure hp3par_iscsi backend with additional configuration' do
      is_expected.to contain_cinder_config('hpe3par_iscsi/param1').with({
        :value => 'value1',
      })
    end
  end

  describe 'hp3par_iscsi backend with cinder type' do
    before :each do
      params.merge!({:manage_volume_type => true})
    end
    it 'should create type with properties' do
      should contain_cinder_type('hp3par_iscsi').with(:ensure => :present, :properties => ['volume_backend_name=hp3par_iscsi'])
    end
  end

end
