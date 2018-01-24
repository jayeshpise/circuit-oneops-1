require './cluster_summary_stats'
require './solr_mbean_summary_stats'
require './rest_client'
require 'logger'

class SolrMetricsCollector

  include Solr::RestClient

  @hostname
  @port
  @medusa_log_file
  @enable_medusa
  @solr_version
  @enable_rest_metrics
  @jmx_medusa_log_file
  @metric_level
  @jolokia_port
  @solr_jmx_port
  @enable_jmx_metrics

  @prefix
  @username
  @password
  @graphite_hosts
  @environment
  @node_ip
  @environment_name
  @datacenter
  @graphite_logfiles_path
  @rotate
  @log_size

  attr_accessor :collections, :cores, :shards, :replicas, :live_nodes, :solr_collection_metric,
                :active_shards_count, :cluster_status_metrics

  #Constructor to initialize this class with input parameters
  def initialize(hostname, port, medusa_log_file, enable_medusa, solr_version, enable_rest_metrics,
                 jmx_medusa_log_file, metric_level, jolokia_port, solr_jmx_port, enable_jmx_metrics, user, password, graphite_hosts,
                 graphite_prefix, oo_env, node_ip, environment_name, oo_dc, graphite_logfiles_path, rotate, log_size)

    @hostname = hostname
    @port = port
    @medusa_log_file = medusa_log_file
    @enable_medusa = enable_medusa
    @solr_version = solr_version
    @enable_rest_metrics = enable_rest_metrics
    @jmx_medusa_log_file = jmx_medusa_log_file
    @metric_level = metric_level
    @jolokia_port = jolokia_port
    @solr_jmx_port = solr_jmx_port
    @enable_jmx_metrics = enable_jmx_metrics

    @username = user
    @password = password
    @graphite_hosts = graphite_hosts
    @prefix = graphite_prefix
    # @environment holds the environment_profile, eg: dev/ prod/ qa/stg
    @environment = oo_env
    @node_ip = node_ip
    # @environment_name holds the user defined environment name. eg: datacenter name in ms-df-solrcloud prod clusters
    @environment_name = environment_name
    @datacenter = oo_dc
    @graphite_logfiles_path = graphite_logfiles_path

  end

  #Primary entrance point to collect all metrics from the cluster
  def collect_all_stats()

    begin

      time = Time.now

      medusaLogWriter = nil
      if (@enable_medusa == true)
        medusaLogger = Logger.new(File.new(@medusa_log_file, File::WRONLY | File::CREAT | File::TRUNC))
        # Ruby logger.formatter supports four input parameters : |severity, datetime, progname, msg|, here, we only need to pass msg into the proc.
        medusaLogger.formatter = proc { |_s, _d, _p, msg| "#{msg}\n" }
        medusaLogWriter = MedusaLogWriter.new(medusaLogger)
      end

      graphiteWriter = nil
      if (@graphite_hosts != nil)
        # @environment holds the environment_profile, eg: dev/ prod/ qa/stg
        # @environment_name holds the user defined environment name. eg: datacenter name in ms-df-solrcloud prod clusters
        graphiteWriter = GraphiteWriter.new(@prefix, @environment, @node_ip, @graphite_hosts, @datacenter, @environment_name)
        graphiteWriter.open_tcp_sockets
      end

      called_node_status_metrics = 0
      if (@enable_rest_metrics == "true")
        get_solr_node_status(time, medusaLogWriter, graphiteWriter)
        called_node_status_metrics += 1
        # Get the metrics from Solr REST APIs
        SolrClusterSummaryStats.get_stats(@hostname, @port, time, medusaLogWriter, graphiteWriter, @solr_version, @collections)
      end

      if (@enable_jmx_metrics == "true")
        if called_node_status_metrics == 0
          get_solr_node_status(time, medusaLogWriter, graphiteWriter)
        end
        jmx_medusaLogWriter = nil
        if (@enable_medusa == true)
          jmx_medusaLogger = Logger.new(File.new(@jmx_medusa_log_file, File::WRONLY | File::CREAT | File::TRUNC))
          # Ruby logger.formatter supports four input parameters : |severity, datetime, progname, msg|, here, we only need to pass msg into the proc.
          jmx_medusaLogger.formatter = proc { |_s, _d, _p, msg| "#{msg}\n" }
          jmx_medusaLogWriter = MedusaLogWriter.new(jmx_medusaLogger)
        end
        mbean_sum_stat_obj = SolrMBeanSummaryStats.new(jmx_medusaLogWriter, graphiteWriter, @metric_level, @jolokia_port, @solr_jmx_port, @solr_version, time)
        mbean_sum_stat_obj.collect_jmx_metrics()
      end

    rescue Exception => e
      puts "collect_all_stats:exception: #{e}"
    ensure
      if (@graphite_hosts != nil)
        graphiteWriter.close_tcp_sockets
      end
    end

  end

  def get_solr_node_status(time, medusaLogWriter, graphiteWriter)
    begin
      # Get the cluster status
      cluster_status = get(@hostname, @port, '/solr/admin/collections?action=CLUSTERSTATUS&wt=json')

      # Get the list of collections from the LIST API
      @collections = cluster_status["cluster"]["collections"].keys

      # Get the json of collections from clusterstatus which includes shard and replica details
      cluster_status_collections = cluster_status["cluster"]["collections"]

      # live nodes in the cluster
      live_nodes = cluster_status["cluster"]["live_nodes"]

      live_nodes_metric = {
          "total.nodes.live" => live_nodes.size
      }

      # Get the nodes states
      # active node count
      # live node count
      # down node count
      # recovering node count
      get_nodes_states(cluster_status_collections, medusaLogWriter, graphiteWriter, time)

      if (medusaLogWriter != nil)
        SolrClusterSummaryStats.write_metrics_to_medusa_log(live_nodes_metric, medusaLogWriter, time, nil)
      end

      if (graphiteWriter != nil)
        graphiteWriter.write_metric('live_nodes', GraphiteWriter::CONST_CLUSTER_SUMMARY, live_nodes.size, time)
      end
    rescue Exception => e
      puts "Solr Nodes Status error : #{e}"
    end
  end

  def get_nodes_states(cluster_status_collections, medusaLogWriter, graphiteWriter, time)

    # Iterate through the collections in the cluster status
    @collections.each do |collection|

      down_nodes = []
      active_nodes = []
      recovering_nodes = []
      recovery_failed_nodes = []

      active_replicas_count = 0
      active_shards_count = 0

      unless cluster_status_collections[collection]["shards"].nil?

        # Get all the shard names
        @shards = cluster_status_collections[collection]["shards"].keys
        shards_list = cluster_status_collections[collection]["shards"]

        @shards.each do |shard|

          unless shards_list[shard]["replicas"].nil?

            if shards_list[shard]["state"] = "active"
              active_shards_count += 1
            end

            # Get all the replicas irrespective if shard is active or not
            @replicas = shards_list[shard]["replicas"].keys
            replicas_list = shards_list[shard]["replicas"]

            @replicas.each do |replica|

              # Check if a node is active/ down/ recovering
              if replicas_list[replica]["state"] == "down"
                if !down_nodes.include?( replicas_list[replica]["core"] )
                  down_nodes.push( replicas_list[replica]["core"] )
                end
              end
              if replicas_list[replica]["state"] == "active"
                if !active_nodes.include?( replicas_list[replica]["core"] )
                  active_nodes.push( replicas_list[replica]["core"] )
                  active_replicas_count += 1
                end
              end
              if replicas_list[replica]["state"] == "recovering"
                if !recovering_nodes.include?( replicas_list[replica]["core"] )
                  recovering_nodes.push( replicas_list[replica]["core"] )
                end
              end
              if replicas_list[replica]["state"] == "recovery_failed"
                if !recovery_failed_nodes.include?( replicas_list[replica]["core"] )
                  recovery_failed_nodes.push( replicas_list[replica]["core"] )
                end
              end
            end
          end
        end
      end

      @cluster_status_metrics = { "total.nodes.down" => {:metric => down_nodes.size},
                                  "total.nodes.active" => {:metric => active_nodes.size},
                                  "total.nodes.recovering" => {:metric => recovering_nodes.size},
                                  "total.active.shards.count" => {:metric => active_shards_count},
                                  "total.active.replicas.count" => {:metric => active_replicas_count},
                                  "total.nodes.recovery.failed" => {:metric => recovery_failed_nodes.size}
      }

      if (medusaLogWriter != nil)
        SolrClusterSummaryStats.write_metrics_to_medusa_log(@cluster_status_metrics, medusaLogWriter, time, collection)
      end

      if (graphiteWriter != nil)
        graphiteWriter.write_collection_specific_metric("down_nodes", GraphiteWriter::CONST_CLUSTER_SUMMARY, down_nodes.size, time, collection)
        graphiteWriter.write_collection_specific_metric("active_nodes", GraphiteWriter::CONST_CLUSTER_SUMMARY, active_nodes.size, time, collection)
        graphiteWriter.write_collection_specific_metric("recovering_nodes", GraphiteWriter::CONST_CLUSTER_SUMMARY, recovering_nodes.size, time, collection)
        graphiteWriter.write_collection_specific_metric("recovery_failed_nodes", GraphiteWriter::CONST_CLUSTER_SUMMARY, recovery_failed_nodes.size, time, collection)
        graphiteWriter.write_collection_specific_metric("shards_count", GraphiteWriter::CONST_CLUSTER_SUMMARY, active_shards_count, time, collection)
        graphiteWriter.write_collection_specific_metric("replicas_count", GraphiteWriter::CONST_CLUSTER_SUMMARY, active_replicas_count, time, collection)
      end

    end
  end

end

