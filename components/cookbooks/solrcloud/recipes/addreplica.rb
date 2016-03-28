#
# Cookbook Name:: solrcloud
# Recipe:: addreplica.rb
#
# The recipie adds replica to the solr cloud.
#
#

ci = node.workorder.ci.ciAttributes;
collection_name = ci[:collection_name]
time = Time.now.getutc.to_i

Chef::Log.info('Add Replica to Solr Cloud ')
begin
  bash 'add_replica' do
    user "#{node['solr']['user']}"
    Chef::Log.info("http://#{node['ipaddress']}:8080/solr/admin/cores?action=CREATE&collection=#{collection_name}&name=#{node['ipaddress']}_#{collection_name}_#{time}")
	  code <<-EOH
	    curl 'http://#{node['ipaddress']}:8080/solr/admin/cores?action=CREATE&collection=#{collection_name}&name=#{node['ipaddress']}_#{collection_name}_#{time}'
	  EOH
    not_if { "#{collection_name}".empty? }
  end
rescue
  Chef::Log.error("Failed to add replica. Collection '#{collection_name}' may not exists.")
ensure
  puts "End of add_replica execution."
end

