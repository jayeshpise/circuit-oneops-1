require 'socket'

class GraphiteWriter

  attr_accessor :graphite_hosts

  CONST_CLUSTER_SUMMARY = 'SOLRCLOUD_SUMMARY'
  CONST_CORE_SUMMARY = "CORE_LEVEL_SUMMARY"

  #Constructor to initialize this class with input parameters
  def initialize(prefix, environment, node_ip, graphite_hosts, datacenter, environment_name)
    @prefix = prefix
    @environment = environment
    @node_ip = node_ip
    @graphite_hosts = graphite_hosts
    @datacenter = datacenter
    @environment_name = environment_name
  end


  # Opens tcp sockets to all graphite servers on the specified port#
  def open_tcp_sockets()

    if (@graphite_hosts.length > 0)

      @tcp_sockets = Array.new
      @graphite_hosts.each do |graphite_host|
        begin
          graphite_host_splits = graphite_host.split(':')
          graphite_server = graphite_host_splits[0]
          port = graphite_host_splits[1]
          tcp_socket = TCPSocket.new(graphite_server, port)
          @tcp_sockets.insert(-1, tcp_socket)
        rescue Exception => e
          puts "open_tcp_sockets:exception: graphite host = #{graphite_host} #{e}"
        end
      end

    end

  end


  # Close tcp sockets to all graphite servers
  def close_tcp_sockets()

    if (@tcp_sockets.length > 0)

      @tcp_sockets.each do |tcp_socket|
        begin
          tcp_socket.close
        rescue Exception => e
          puts "close_tcp_sockets:exception: #{e}"
        end
      end

    end

  end


  # write metric to graphite
  def write_metric(metric_name, level, value, time)
    write_to_graphite( construct_metric_name(metric_name, level), value.to_s, time)
  end

  # write cluster level metrics specific to each collection
  def write_collection_specific_metric(metric_name, level, value, time, collection)
    write_to_graphite( construct_collection_metric_name(metric_name, level, collection), value.to_s, time)
  end


  # Iterates through a list of graphite hosts and writes the metrics out to the graphite server(s)
  private
  def write_to_graphite(key, value, time = Time.now)

    if (@tcp_sockets.length > 0)

      @tcp_sockets.each do |tcp_socket|

        begin
          tcp_socket.write("#{key} #{value.to_f} #{time.to_i}\n")
            #puts key, value, time.to_i
        rescue Exception => e
          puts "write_to_graphite:exception: #{e}"
        end
      end

    end

  end

  #Construct the metric name
  #May be cluster level (1), node level (2) or bucket level (3)
  private
  def construct_metric_name(metric_name, level)
    # The logic for adding 'DF-UI.' is going to be the responsibility of the cron job
    # invoking this ruby script.
    final_metric_name = "#{@prefix}.#{@environment}.solrcloud.#{@environment_name}."

    case level
      when CONST_CLUSTER_SUMMARY
        final_metric_name += metric_name
      when CONST_CORE_SUMMARY
        # Appending the node ip to distinguish the metrics coming from different nodes in case if we need to sum the values of a metric
        # Otherwise one value will overwrite the value which was previously received since the path and the metrics will remain same.
        final_metric_name += "#{metric_name}.#{@node_ip}"
    end

    return final_metric_name
  end

  #Construct the metric name
  #Only the collection level (1)
  private
  def construct_collection_metric_name(metric_name, level, collection)
    # The logic for adding 'DF-UI.' is going to be the responsibility of the cron job
    # invoking this ruby script.
    final_metric_name = "#{@prefix}.#{@environment}.solrcloud.#{@environment_name}."

    case level
      when CONST_CLUSTER_SUMMARY
        # Appending the collection name along with the metric_name since we should not allow the node status metric to be overwritten by the values
        # from other collection for the same metric. We want to uniquely identify the node status metrics for each collection to sum it up.
        # eg: sum of all down nodes. We will get the down_nodes specific to a collection.
        final_metric_name += "#{metric_name}.#{collection}"
      when CONST_CORE_SUMMARY
        # Appending the node ip along with collection to distinguish the metrics coming from different nodes/ collection combination
        # in case if we need to sum the values of a metric.
        # eg: select-timeouts. We need the sum of all timeouts from all the cores. We are getting the select timeout for any core.
        # To identify a core uniquely we need both node-ip and collection combination.
        # Otherwise one value will overwrite the value which was previously received since the path and the metrics will remain same.
        final_metric_name += "#{metric_name}.#{@node_ip}-#{collection}"
    end

    return final_metric_name
  end

end
