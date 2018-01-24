require "/home/oneops/circuit-oneops-1/components/cookbooks/os/libraries/util.rb"


rfcCi = $node['workorder']['rfcCi']
host_name = "#{$node['workorder']['box']['ciName']}-#{$node['workorder']['cloud']['ciId']}-#{$node['workorder']['rfcCi']['ciName'].split('-').last.to_i.to_s}-#{rfcCi['ciId']}"
fqdn_name = "#{host_name}.#{$node['customer_domain']}"

data = YAML::load(File.read("/home/oneops/circuit-oneops-1/components/cookbooks/os/test/integration/add/serverspec/checklist.yml"))
limits = {}

# Directory and file checks
checks = data['files']
checks.each do |check|
  if check['type'] == 'd'
    describe file(check['name']) do
      it { should be_directory  }
      it { should be_mode check['mode'] }
      it { should be_owned_by check['owner'] }
      it { should be_grouped_into check['group'] }
    end
  else
    describe file(check['name']) do
      it { should be_file }
      it { should be_mode check['mode'] }
      it { should be_owned_by check['owner'] }
      it { should be_grouped_into check['group'] }
    end
  end
end

# Config file contents

#--- add-config-files.rb
env_vars_content = get_cloud_env_vars_content($node)
oo_vars_content = get_oo_vars_content($node)
oo_vars_conf_content = get_oo_vars_conf_content($node)

describe file('/etc/profile.d/oneops_compute_cloud_service.sh') do
  its(:content) { should eq env_vars_content }
end
describe file('/etc/profile.d/oneops.sh') do
  its(:content) { should eq oo_vars_content }
end
describe file('/etc/profile.d/oneops.conf') do
  its(:content) { should eq oo_vars_conf_content }
end
describe file("/etc/oneops") do
  it { should be_symlink }
end
#--- add-config-files.rb

#--- network.rb
host_cmd = `hostname -f`

describe file('/etc/cloud/cloud.cfg') do
  its(:content) { should match /preserve_hostname: true/ }
end
describe file('/etc/cloud/cloud.cfg.d/99_hostname.cfg') do
  its(:content) { should eq "hostname: #{host_name.downcase}\nfqdn: #{fqdn_name.downcase}\n" }
end
describe file('/opt/oneops/domain') do
  its(:content) { should eq "#{$node['customer_domain']}\n" }
end
describe "FQDN" do
  it "Should equal #{fqdn_name.downcase}" do
    expect(host_cmd.downcase.strip).to be == fqdn_name.downcase.strip
  end
end
#--- network.rb

#--- time.rb
timezone = $node['workorder']['rfcCi']['ciAttributes']['timezone']

describe file('/etc/localtime') do
  it { should be_symlink }
  it { should be_linked_to "/usr/share/zoneinfo/#{timezone}" }
end
describe file('/etc/sysconfig/clock') do
  its(:content) { should eq "ZONE=\"#{timezone}\"\n" }
end
#--- time.rb

#--- kernel.rb
if $node['workorder']['rfcCi']['ciAttributes'].has_key?('limits') && !$node['workorder']['rfcCi']['ciAttributes']['limits'].empty? && JSON.parse($node['workorder']['rfcCi']['ciAttributes']['limits']) != limits
  limits = JSON.parse($node['workorder']['rfcCi']['ciAttributes']['limits'])
  limits.each do |lim|
    describe file('/etc/security/limits.d/oneops.conf') do
      its(:content) { should match /#{lim}/ }
    end
  end
else
  describe file('/etc/security/limits.d/oneops.conf') do
    its(:content) { should eq '' }
  end
end
#--- kernel.rb

# Config file contents end

# Yum packages
packages = data['packages']
packages.each do |a_package|
  describe package(a_package) do
    it { should be_installed }
  end
end

# Gems
gems = data['gems']
gems.each do |a_gem|
  describe package(a_gem) do
    it { should be_installed.by('gem') }
  end
end

# Proxys
# TODO
# Parse repo map and check against yum and gem
describe user("oneops") do
  it { should exist }
end

