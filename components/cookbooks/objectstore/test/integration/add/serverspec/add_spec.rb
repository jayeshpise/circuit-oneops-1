is_windows = ENV['OS'] == 'Windows_NT'
$circuit_path = "#{is_windows ? 'C:/Cygwin64' : ''}/home/oneops"
require "#{$circuit_path}/circuit-oneops-1/components/spec_helper.rb"

OBJECTSTORE_EXE_FILE   = '/usr/local/bin/objectstore'.freeze
OBJECTSTORE_CREDS_FILE = '/etc/objectstore_creds.json'.freeze

TEST_CONTAINER_NAME    = "test-#{$node['workorder']['rfcCi']['rfcId']}".freeze
TEST_BLOB_NAME         = 'test-blob'.freeze
TEST_BLOB_SIZE         = '10M'.freeze

OUTPUT                 = "usage: \n"                                            \
                         "objectstore list <container>\n"                       \
                         "objectstore upload <directory/file> <container>\n"    \
                         "objectstore download <container/blob> <local-path>\n" \
                         "objectstore delete <container>/<blob>\n".freeze

describe file(OBJECTSTORE_EXE_FILE) do
  it { should exist }
end

describe file(OBJECTSTORE_EXE_FILE) do
  it { should be_executable }
end

describe file(OBJECTSTORE_CREDS_FILE) do
  it { should exist }
end

describe command(OBJECTSTORE_EXE_FILE) do
  its(:stdout) { should eq OUTPUT }
end

describe command("#{OBJECTSTORE_EXE_FILE} --help") do
  its(:exit_status) { should eq 0 }
end

describe command("fallocate -l #{TEST_BLOB_SIZE} #{TEST_BLOB_NAME}") do
  its(:exit_status) { should eq 0 }
end

describe command("#{OBJECTSTORE_EXE_FILE} upload #{TEST_BLOB_NAME} #{TEST_CONTAINER_NAME}") do
  its(:exit_status) { should eq 0 }
end

describe command("#{OBJECTSTORE_EXE_FILE} download #{TEST_CONTAINER_NAME}/#{TEST_BLOB_NAME} ./") do
  its(:exit_status) { should eq 0 }
end

describe command("#{OBJECTSTORE_EXE_FILE} delete #{TEST_CONTAINER_NAME}") do
  its(:exit_status) { should eq 0 }
end

describe command("rm -f #{TEST_BLOB_NAME}") do
  its(:exit_status) { should eq 0 }
end
