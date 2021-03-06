require 'puppet'
require 'spec_helper'
require 'puppet/provider/nova'
require 'rspec/mocks'

describe Puppet::Provider::Nova do

  def klass
    described_class
  end

  let :credential_hash do
    {
      'auth_uri'     => 'https://192.168.56.210:35357/v2.0/',
      'project_name' => 'admin_tenant',
      'username'     => 'admin',
      'password'     => 'password',
    }
  end

  let :auth_endpoint do
    'https://192.168.56.210:35357/v2.0/'
  end

  let :credential_error do
    /Nova types will not work/
  end

  after :each do
    klass.reset
  end

  describe 'when determining credentials' do

    it 'should fail if config is empty' do
      conf = {}
      klass.expects(:nova_conf).returns(conf)
      expect do
        klass.nova_credentials
      end.to raise_error(Puppet::Error, credential_error)
    end

    it 'should fail if config does not have keystone_authtoken section.' do
      conf = {'foo' => 'bar'}
      klass.expects(:nova_conf).returns(conf)
      expect do
        klass.nova_credentials
      end.to raise_error(Puppet::Error, credential_error)
    end

    it 'should fail if config does not contain all auth params' do
      conf = {'keystone_authtoken' => {'invalid_value' => 'foo'}}
      klass.expects(:nova_conf).returns(conf)
      expect do
       klass.nova_credentials
      end.to raise_error(Puppet::Error, credential_error)
    end

    it 'should use specified uri in the auth endpoint' do
      conf = {'keystone_authtoken' => credential_hash}
      klass.expects(:nova_conf).returns(conf)
      expect(klass.get_auth_endpoint).to eq(auth_endpoint)
    end

  end

  describe 'when invoking the nova cli' do

    it 'should set auth credentials in the environment' do
      authenv = {
        :OS_AUTH_URL     => auth_endpoint,
        :OS_USERNAME     => credential_hash['username'],
        :OS_PROJECT_NAME => credential_hash['project_name'],
        :OS_PASSWORD     => credential_hash['password'],
      }
      klass.expects(:get_nova_credentials).with().returns(credential_hash)
      klass.expects(:withenv).with(authenv)
      klass.auth_nova('test_retries')
    end

    ['[Errno 111] Connection refused',
     '(HTTP 400)'].reverse.each do |valid_message|
      it "should retry when nova cli returns with error #{valid_message}" do
        klass.expects(:get_nova_credentials).with().returns({})
        klass.expects(:sleep).with(10).returns(nil)
        klass.expects(:nova).twice.with(['test_retries']).raises(
          Exception, valid_message).then.returns('')
        klass.auth_nova('test_retries')
      end
    end

  end

  describe 'when parse a string line' do
    it 'should return the same string' do
      res = klass.str2hash("zone1")
      expect(res).to eq("zone1")
    end

    it 'should return the string without quotes' do
      res = klass.str2hash("'zone1'")
      expect(res).to eq("zone1")
    end

    it 'should return the same string' do
      res = klass.str2hash("z o n e1")
      expect(res).to eq("z o n e1")
    end

    it 'should return a hash' do
      res = klass.str2hash("a=b")
      expect(res).to eq({"a"=>"b"})
    end

    it 'should return a hash with containing spaces' do
      res = klass.str2hash("a b = c d")
      expect(res).to eq({"a b "=>" c d"})
    end

    it 'should return the same string' do
      res = klass.str2list("zone1")
      expect(res).to eq("zone1")
    end

    it 'should return a list of strings' do
      res = klass.str2list("zone1, zone2")
      expect(res).to eq(["zone1", "zone2"])
    end


    it 'should return a list of strings' do
      res = klass.str2list("zo n e1,    zone2    ")
      expect(res).to eq(["zo n e1", "zone2"])
    end

    it 'should return a hash with multiple keys' do
      res = klass.str2list("a=b, c=d")
      expect(res).to eq({"a"=>"b", "c"=>"d"})
    end

    it 'should return a single hash' do
      res = klass.str2list("a=b")
      expect(res).to eq({"a"=>"b"})
    end
  end

  describe 'when parsing cli output' do

    it 'should return a list with hashes' do
      output = <<-EOT
+----+-------+-------------------+
| Id | Name  | Availability Zone |
+----+-------+-------------------+
| 1  | haha  | haha2             |
| 2  | haha2 | -                 |
+----+-------+-------------------+
      EOT
      res = klass.cliout2list(output)
      expect(res).to eq([{"Id"=>"1", "Name"=>"haha", "Availability Zone"=>"haha2"},
                     {"Id"=>"2", "Name"=>"haha2", "Availability Zone"=>""}])
    end

    it 'should return a list with hashes' do
      output = <<-EOT
+----+-------+-------------------+-------+--------------------------------------------------+
| Id | Name  | Availability Zone | Hosts | Metadata                                         |
+----+-------+-------------------+-------+--------------------------------------------------+
| 16 | agg94 |  my_-zone1        |       | 'a=b', 'availability_zone= my_-zone1', 'x_q-r=y' |
+----+-------+-------------------+-------+--------------------------------------------------+
EOT
      res = klass.cliout2list(output)
      expect(res).to eq([{"Id"=>"16",
                       "Name"=>"agg94",
                       "Availability Zone"=>"my_-zone1",
                       "Hosts"=>"",
                       "Metadata"=> {
                         "a"=>"b",
                         "availability_zone"=>" my_-zone1",
                         "x_q-r"=>"y"
                         }
                     }])
    end

    it 'should return a empty list' do
      output = <<-EOT
+----+------+-------------------+
| Id | Name | Availability Zone |
+----+------+-------------------+
+----+------+-------------------+
      EOT
      res = klass.cliout2list(output)
      expect(res).to eq([])
    end

    it 'should return a empty list because no input available' do
      output = <<-EOT
      EOT
      res = klass.cliout2list(output)
      expect(res).to eq([])
    end

    it 'should return a list with hashes' do
      output = <<-EOT
+----+----------------+-------------------+
| Id | Name           | Availability Zone |
+----+----------------+-------------------+
| 6  | my             | zone1             |
| 8  | my2            | -                 |
+----+----------------+-------------------+
      EOT
      res = klass.cliout2list(output)
      expect(res).to eq([{"Id"=>"6", "Name"=>"my", "Availability Zone"=>"zone1"},
                     {"Id"=>"8", "Name"=>"my2", "Availability Zone"=>""}])
    end
  end

  describe 'when parsing cli output with cells enabled' do

    it 'should return a list with hashes' do
      output = <<-EOT
+-------------+----------------+-------------------+
| Id          | Name           | Availability Zone |
+-------------+----------------+-------------------+
| api!cell@1  | api!cell@haha  | haha2             |
| api!cell@2  | api!cell@haha2 | -                 |
+-------------+----------------+-------------------+
      EOT
      res = klass.cliout2list(output)
      expect(res).to eq([{"Id"=>"api!cell@1", "Name"=>"api!cell@haha", "Availability Zone"=>"haha2"},
                     {"Id"=>"api!cell@2", "Name"=>"api!cell@haha2", "Availability Zone"=>""}])
    end

    it 'should return a list with hashes' do
      output = <<-EOT
+-------------+----------------+-------------------+-------+--------------------------------------------------+
| Id          | Name           | Availability Zone | Hosts | Metadata                                         |
+-------------+----------------+-------------------+-------+--------------------------------------------------+
| api!cell@16 | api!cell@agg94 |  my_-zone1        |       | 'a=b', 'availability_zone= my_-zone1', 'x_q-r=y' |
+-------------+----------------+-------------------+-------+--------------------------------------------------+
EOT
      res = klass.cliout2list(output)
      expect(res).to eq([{"Id"=>"api!cell@16",
                       "Name"=>"api!cell@agg94",
                       "Availability Zone"=>"my_-zone1",
                       "Hosts"=>"",
                       "Metadata"=> {
                         "a"=>"b",
                         "availability_zone"=>" my_-zone1",
                         "x_q-r"=>"y"
                         }
                     }])
    end

    it 'should return a empty list' do
      output = <<-EOT
+----+------+-------------------+
| Id | Name | Availability Zone |
+----+------+-------------------+
+----+------+-------------------+
      EOT
      res = klass.cliout2list(output)
      expect(res).to eq([])
    end

    it 'should return a empty list because no input available' do
      output = <<-EOT
      EOT
      res = klass.cliout2list(output)
      expect(res).to eq([])
    end

    it 'should return a list with hashes' do
      output = <<-EOT
+-------------+-------------------------+-------------------+
| Id          | Name                    | Availability Zone |
+-------------+-------------------------+-------------------+
| api!cell@6  | api!cell@my             | zone1             |
| api!cell@8  | api!cell@my2            | -                 |
+-------------+-------------------------+-------------------+
      EOT
      res = klass.cliout2list(output)
      expect(res).to eq([{"Id"=>"api!cell@6", "Name"=>"api!cell@my", "Availability Zone"=>"zone1"},
                     {"Id"=>"api!cell@8", "Name"=>"api!cell@my2", "Availability Zone"=>""}])
    end
  end
end
