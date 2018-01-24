user_dir = node.workorder.payLoad.DependsOn.select {|c| c[:ciClassName] =~ /User/ }.first[:ciAttributes]['username']
Chef::Log.info("user home directory : #{user_dir}")
solr_pack_dir = "#{user_dir}/solr_pack"
if node.workorder.has_key?("rfcCi")
  ci = node.workorder.rfcCi.ciAttributes;
  actionName = node.workorder.rfcCi.rfcAction
else
  ci = node.workorder.ci.ciAttributes;
  actionName = node.workorder.actionName
end

# create /app/solr_pack/ directory
deployment_status_file_contents = "action=#{actionName}\nTime=#{Time.new}\n"
directory solr_pack_dir do
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end
# create /app/solr_pack/deployment_status.txt to track the deployment progress
file "#{solr_pack_dir}/deployment_status.txt" do
  content deployment_status_file_contents
  owner 'root'
  group 'root'
  mode '0755'
  action :create
end
