require 'rubygems'
require 'net/https'
require 'json'

cloud_name = node[:workorder][:cloud][:ciName]
Chef::Log::info("kiv:cloud name is " + cloud_name)

smesh_service = node[:workorder][:services][:servicemeshcloudservice]
if !smesh_service.nil? && !smesh_service[cloud_name].nil?
  mesh_cloud_service = node[:workorder][:services][:servicemeshcloudservice][cloud_name][:ciAttributes]
  Chef::Log::info("mesh_artifact_url == " + mesh_cloud_service[:mesh_artifact_url])
  Chef::Log::info("sr_url_prod == " + mesh_cloud_service[:sr_url_prod])
  Chef::Log::info("sr_url_nonprod == " + mesh_cloud_service[:sr_url_nonprod])
else
  Chef::Log.error("servicemeshcloudservice cloud service not defined for this cloud, so cannot proceed with deployment")
  exit 1
end


### Create service mesh root directory ###
serviceMeshRootDir = "#{node['service-mesh']['service-mesh-root']}"
Chef::Log::info("Creating the root directory for service mesh #{serviceMeshRootDir} if not present...")
directory serviceMeshRootDir do
	owner 'root'
	group 'root'
	mode '0777'
	recursive true
	action :create
end
Chef::Log::info("Service mesh root directory created successfully")

linkerdConfigPath = serviceMeshRootDir + "/linkerd-sr.yaml"

srUrlProd = mesh_cloud_service[:sr_url_prod]
srUrlNonprod = mesh_cloud_service[:sr_url_nonprod]
Chef::Log::info("Prod url is #{srUrlProd}")
Chef::Log::info("Nonprod url is #{srUrlNonprod}")

### check if the environment is prod or nonprod ###
profile = node[:workorder][:payLoad][:Environment][0][:ciAttributes][:profile].downcase
Chef::Log.info("Got env profile as #{profile}")
isProdEnv = "false"
if profile.include? "prod"
    Chef::Log.info("Deployment taking place in production environment")
    isProdEnv = "true"
end
Chef::Log.info("Final isProdEnv= #{isProdEnv}")

### parse all tenants and make available for linkerd config template ###
aTenant = []
  JSON.parse("#{node['service-mesh']['tenants']}").each do |l|
    larr = l.split(" ")
    aTenant.push(larr)
  end

tenantConfigs = ""
aTenant.each do |a_tenant|
    tenantConfigs = tenantConfigs + "  - appKey: #{a_tenant[0]}" + "\n    "
    tenantConfigs = tenantConfigs + "envName: #{a_tenant[1]}\n    "
    tenantConfigs = tenantConfigs + "ingressAddr: #{a_tenant[2]}\n"
end

template linkerdConfigPath do
  source 'linkerd-sr-yaml.erb'
  variables(:tenant_configs => "#{tenantConfigs}",
            :sr_prod_url => "#{srUrlProd}",
            :sr_nonprod_url => "#{srUrlNonprod}",
            :is_prod_env => "#{isProdEnv}")
end

### Download mesh jar file ###
meshRepoUrl = mesh_cloud_service[:mesh_artifact_url]
meshVersion = "#{node['service-mesh']['service-mesh-version']}"
meshJarNexusUrl = meshRepoUrl + "/" + meshVersion + "/soa-linkerd-" + meshVersion + ".jar"
Chef::Log::info("Service mesh artifact remote url: #{meshJarNexusUrl}")

remote_file "#{serviceMeshRootDir}/soa-linkerd-#{meshVersion}.jar" do
	source meshJarNexusUrl
	owner 'root'
	group 'root'
	mode '0777'
	action :create_if_missing
end

### service mesh daemon ###
jobLogPath = serviceMeshRootDir + "/service-mesh.log"
meshLocalPath = "#{serviceMeshRootDir}/soa-linkerd-#{node['service-mesh']['service-mesh-version']}.jar"

Chef::Log::info("Adding service-mesh initd script")
template '/etc/init.d/servicemesh' do
  source 'servicemesh-init.erb'
  owner 'root'
  group 'root'
  mode 00755
  variables(:start_mesh_command => "java -Dcom.twitter.util.events.sinkEnabled=false -jar #{meshLocalPath} #{linkerdConfigPath} > #{jobLogPath} 2>&1 &",
            :grep_string_mesh_process => "/home/app/service-mesh/soa-linkerd-#{node['service-mesh']['service-mesh-version']}.jar ")
end

execute 'enableMeshDaemon' do
	command 'chkconfig --add servicemesh'
	user	'root'
end


### Start Service Mesh process ###
include_recipe "service-mesh::restart-service-mesh-process"

### Verify if the process started successfully ###
include_recipe "service-mesh::status"

### END ###