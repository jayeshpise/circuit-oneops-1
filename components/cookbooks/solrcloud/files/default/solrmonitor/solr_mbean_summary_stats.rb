
require 'json'
require 'set'
require './rest_client'
require './medusa_log_writer'

class SolrMBeanSummaryStats

    include Solr::RestClient

    @medusa_log_writer
    @metric_level
    @jolokia_port
    @solr_jmx_port
    @solr_version
    @time
    @graphite_writer

    # Constructor to initialize this class with input parameters
    def initialize(medusa_log_writer, graphite_writer, metric_level, jolokia_port, solr_jmx_port, solr_version, time)
        @medusa_log_writer = medusa_log_writer
        @graphite_writer = graphite_writer
        @metric_level = metric_level
        @jolokia_port = jolokia_port
        @solr_jmx_port = solr_jmx_port
        @solr_version = solr_version
        @time = time
    end

    # Collect jmx metrics.
    def collect_jmx_metrics

        metric_type_to_solr_core_mbean_attr_map = get_mbeanmap()
        collect_solr_core_jmx_metrics(metric_type_to_solr_core_mbean_attr_map)
    end


    def get_mbeanmap()
        if (is_solr7?())
            return get_mbeanmap_for_solr7()
        elsif (solr_version_high())
            return get_mbeanmap_for_higherversion()
        else
            return get_mbeanmap_for_lowerversion()
        end
    end

    def get_mbeanmap_for_solr7()

        metric_type_to_solr_core_mbean_attr_map = {
            "add_aggr_metrics" => {
                # category, scope, name are the elements of the mbean object
                "category=QUERY,scope=/get,name=requestTimes" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=QUERY,scope=/get,name=timeouts" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=QUERY,scope=/get,name=errors" =>
                    ["Count, OneMinuteRate, FiveMinuteRate, FifteenMinuteRate"],
                "category=QUERY,scope=/get,name=clientErrors" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=QUERY,scope=/get,name=serverErrors" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=QUERY,scope=/select,name=requestTimes" =>
                    ["Count, OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=QUERY,scope=/select,name=timeouts" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=QUERY,scope=/select,name=errors" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=QUERY,scope=/select,name=clientErrors" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=QUERY,scope=/select,name=serverErrors" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=UPDATE,scope=/update,name=requestTimes" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=UPDATE,scope=/update/json,name=timeouts" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=UPDATE,scope=update,name=serverErrors" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=UPDATE,scope=update,name=clientErrors" =>
                    ["Count,OneMinuteRate,FiveMinuteRate,FifteenMinuteRate"],
                "category=CACHE,scope=searcher,name=fieldValueCache" =>
                    ["hits,hitratio,evictions,size"],
                "category=CACHE,scope=searcher,name=filterCache" =>
                    ["hits,hitratio,evictions,size"],
                "category=CACHE,scope=searcher,name=documentCache" =>
                    ["hits,hitratio,evictions,size"],
                "category=CACHE,scope=searcher,name=queryResultCache" =>
                    ["hits,hitratio,evictions,size"],
                "category=CACHE,scope=searcher,name=perSegFilter" =>
                    ["hits,hitratio,evictions"],
                "category=CACHE,scope=core,name=fieldCache" =>
                    ["total_size,entries_count"],
                "category=UPDATE,scope=updateHandler,name=softAutoCommits" =>
                    ["Value"],
                "category=UPDATE,scope=updateHandler,name=autoCommits" =>
                    ["Value"],
                "category=SEARCHER,scope=searcher,name=deletedDocs" =>
                    ["Value"],
                "category=SEARCHER,scope=searcher,name=numDocs" =>
                    ["Value"],
                "category=SEARCHER,scope=searcher,name=maxDoc" =>
                    ["Value"],
                "category=ADMIN,scope=/admin/segments,name=requests" =>
                    ["Count"]
                # "category=INDEX,name=major.deletedDocs,scope=merge" =>
                #     ["Count,OneMinuteReate,FiveMinuteRate,FifteenMinuteRate"],
                # "category=INDEX,name=major.running.segments,scope=merge" =>
                #     ["Value"],
                # "category=INDEX,name=major.docs,scope=merge" =>
                #     ["Count,OneMinuteReate,FiveMinuteRate,FifteenMinuteRate"],
                # "category=INDEX,name=major,scope=merge" =>
                #     ["Count,OneMinuteReate,FiveMinuteRate,FifteenMinuteRate"],
                # "category=INDEX,name=major.running.docs,scope=merge" =>
                #     ["Value"],
                # "category=INDEX,name=minor.running,scope=merge" =>
                #     ["Value"],
                # "category=INDEX,name=minor.running.segments,scope=merge" =>
                #     ["Value"],
                # "category=INDEX,name=minor,scope=merge" =>
                #     ["Count, OneMinuteReate, FiveMinuteRate, FifteenMinuteRate"],
                # "category=INDEX,name=minor.running.docs,scope=merge" =>
                #     ["Value"],
                # "category=INDEX,name=minor.running,scope=merge" =>
                #     ["Value"],

            },
            "avg_aggr_metrics" => {
                # category, scope, name are the elements of the mbean object
                "category=QUERY,scope=/get,name=requestTimes" =>
                    ["95thPercentile,99thPercentile"],
                "category=QUERY,scope=/select,name=requestTimes" =>
                    ["95thPercentile,99thPercentile"],
                "category=UPDATE,scope=/update,name=requestTimes" =>
                    ["95thPercentile,99thPercentile"]
            }
        }
        return metric_type_to_solr_core_mbean_attr_map

    end


    # Get mbean map object for solr higher versions from 6.4 onwards.
    def get_mbeanmap_for_higherversion
        metric_type_to_solr_core_mbean_attr_map = {
            "add_aggr_metrics" => {
                # category, scope, name are the elements of the mbean object
                "category=QUERY,scope=/get,name=org.apache.solr.handler.RealTimeGetHandler" =>
                ["requests,5minRateRequestsPerSecond,15minRateRequestsPerSecond,timeouts,errors,clientErrors,serverErrors"],
                "category=QUERY,scope=/select,name=org.apache.solr.handler.component.SearchHandler" =>
                ["requests,5minRateRequestsPerSecond,15minRateRequestsPerSecond,timeouts,errors,clientErrors,serverErrors"],
                "category=UPDATE,scope=/update,name=org.apache.solr.handler.UpdateRequestHandler" =>
                ["requests,5minRateRequestsPerSecond,15minRateRequestsPerSecond,timeouts,errors,clientErrors,serverErrors"],
                "category=CACHE,scope=fieldValueCache,name=org.apache.solr.search.FastLRUCache" =>
                ["hits,hitratio,evictions"],
                "category=CACHE,scope=filterCache,name=org.apache.solr.search.FastLRUCache" =>
                ["hits,hitratio,evictions"],
                "category=CACHE,scope=documentCache,name=org.apache.solr.search.LRUCache" =>
                ["hits,hitratio,evictions"],
                "category=CACHE,scope=queryResultCache,name=org.apache.solr.search.LRUCache" =>
                ["hits,hitratio,evictions"],
                "category=CACHE,scope=perSegFilter,name=org.apache.solr.search.LRUCache" =>
                ["hits,hitratio,evictions"],
                "category=UPDATE,scope=updateHandler,name=org.apache.solr.update.DirectUpdateHandler2" =>
                ["commits,soft autocommits"],
                "category=ADMIN,scope=/admin/segments,name=org.apache.solr.handler.admin.SegmentsInfoRequestHandler" =>
                ["requests"],
                "category=CORE,scope=searcher,name=org.apache.solr.search.SolrIndexSearcher" =>
                ["deletedDocs,maxDoc,numDocs"],
                "category=CACHE,scope=fieldCache,name=org.apache.solr.search.SolrFieldCacheMBean" =>
                ["entries_count,total_size"]
            },
            "avg_aggr_metrics" => {
                # category, scope, name are the elements of the mbean object
                "category=QUERY,scope=/get,name=org.apache.solr.handler.RealTimeGetHandler" =>
                ["95thPcRequestTime,99thPcRequestTime"],
                "category=QUERY,scope=/select,name=org.apache.solr.handler.component.SearchHandler" =>
                ["95thPcRequestTime,99thPcRequestTime"],
                "category=UPDATE,scope=/update,name=org.apache.solr.handler.UpdateRequestHandler" =>
                ["95thPcRequestTime,99thPcRequestTime"]
            }
        }
        return metric_type_to_solr_core_mbean_attr_map
    end

    # Get mbean map object for lower than solr version 6.4 version.
    def get_mbeanmap_for_lowerversion
        metric_type_to_solr_core_mbean_attr_map = {
            "add_aggr_metrics" => {
                "type=/get,id=org.apache.solr.handler.RealTimeGetHandler" =>
                ["requests,5minRateReqsPerSecond,15minRateReqsPerSecond,timeouts,errors,clientErrors,serverErrors"],
                "type=/select,id=org.apache.solr.handler.component.SearchHandler" =>
                ["requests,5minRateReqsPerSecond,15minRateReqsPerSecond,timeouts,errors,clientErrors,serverErrors"],
                "type=/update,id=org.apache.solr.handler.UpdateRequestHandler" =>
                ["requests,5minRateReqsPerSecond,15minRateReqsPerSecond,timeouts,errors,clientErrors,serverErrors"],
                "type=fieldValueCache,id=org.apache.solr.search.FastLRUCache" =>
                ["hits,hitratio,evictions"],
                "type=filterCache,id=org.apache.solr.search.FastLRUCache" =>
                ["hits,hitratio,evictions"],
                "type=documentCache,id=org.apache.solr.search.LRUCache" =>
                ["hits,hitratio,evictions"],
                "type=queryResultCache,id=org.apache.solr.search.LRUCache" =>
                ["hits,hitratio,evictions"],
                "type=perSegFilter,id=org.apache.solr.search.LRUCache" =>
                ["hits,hitratio,evictions"],
                "type=updateHandler,id=org.apache.solr.update.DirectUpdateHandler2" =>
                ["commits,soft autocommits"],
                "type=/admin/segments,id=org.apache.solr.handler.admin.SegmentsInfoRequestHandler" =>
                ["requests"],
                "type=fieldCache,id=org.apache.solr.search.SolrFieldCacheMBean" =>
                ["entries_count"]
            },
            "avg_aggr_metrics" => {
                "type=/get,id=org.apache.solr.handler.RealTimeGetHandler" =>
                ["95thPcRequestTime,99thPcRequestTime"],
                "type=/select,id=org.apache.solr.handler.component.SearchHandler" =>
                ["95thPcRequestTime,99thPcRequestTime"],
                "type=/update,id=org.apache.solr.handler.UpdateRequestHandler" =>
                ["95thPcRequestTime,99thPcRequestTime"]
            }
        }
        return metric_type_to_solr_core_mbean_attr_map
    end

    # Collect solr core JMX metrics.
    def collect_solr_core_jmx_metrics(metric_type_to_solr_core_mbean_attr_map)
        collections, collection_to_core_name_map = execute_solr_jmx_list_request()
        if @metric_level == "CollectionLevel"
            # If the metric level is equal to 'CollectionLevel' then aggregating the metrics of all cores for each collection on a node.
            collections.each do |collection_name|
                updated_metric_type_to_solr_core_mbean_attr_map = construct_jmx_metrics_with_core_name_as_id(metric_type_to_solr_core_mbean_attr_map, collection_name, collection_to_core_name_map)
                solr_core_mbean_bulk_request, metric_type_to_mbean_type_obj = create_solr_core_mbean_bulkrequest_and_mbeantype_list(updated_metric_type_to_solr_core_mbean_attr_map, collection_name)
                execute_solr_core_jmx_read_request(solr_core_mbean_bulk_request, metric_type_to_mbean_type_obj, collection_name)
            end
        else
            # If the metric level is not equal to 'CollectionLevel' then the other option 'ClusterLevel' was choosen.
            # Hence, aggregating the metrics at cluster level. i.e, For all cores on a node.
            solr_core_mbean_bulk_request, metric_type_to_mbean_type_obj = create_solr_core_mbean_bulkrequest_and_mbeantype_list(metric_type_to_solr_core_mbean_attr_map, nil)
            execute_solr_core_jmx_read_request(solr_core_mbean_bulk_request, metric_type_to_mbean_type_obj, nil)
        end
    end

    # ruby doesn't support deep copying on objects using dup. dup will copy the object to another one without pointing to the same reference.
    # This method will only construct the mbean type to solr mbean attr map for add aggregation type metrics.
    # This can be extended to have similar functionaly with avg aggregation metric types as well.
    def construct_jmx_metrics_with_core_name_as_id(metric_type_to_solr_core_mbean_attr_map, collection_name, collection_to_core_name_map)

        if (is_solr7?())
            return metric_type_to_solr_core_mbean_attr_map
        end

        updated_map = metric_type_to_solr_core_mbean_attr_map.dup
        metric_type_to_solr_core_add_agg_map = metric_type_to_solr_core_mbean_attr_map["add_aggr_metrics"].dup
        cores = collection_to_core_name_map[collection_name]
        cores.each do |core|
            if solr_version_high()
                size_in_bytes_mbean_attr_map = {
                    "category=CORE,scope=core,name=#{core}" =>
                        ["sizeInBytes"]
                }
                metric_type_to_solr_core_add_agg_map.merge!(size_in_bytes_mbean_attr_map)
            end
        end
        updated_map["add_aggr_metrics"] = metric_type_to_solr_core_add_agg_map
        return updated_map

    end

    def execute_solr_jmx_list_request()
        if (is_solr7?())

            return execute_solr_jmx_list_request_for_solr7()
        else
            return execute_solr_jmx_list_request_for_6x_lower()
        end
    end

    # This method returns the collection names of the cores on this node. 
    # Note: We can retrieve the cores and the whole mbeans list with its stat when it is required.
    def execute_solr_jmx_list_request_for_6x_lower()
        mbean_category_to_mbean_attr_map = Hash.new()
        collection_to_core_name_map = Hash.new()
        jmx_list_req_payload = {
            "type" => "list",
            "target" => {
                "url" => "service:jmx:rmi:///jndi/rmi://127.0.0.1:#{@solr_jmx_port}/jmxrmi"
            }
        }
        jmx_list_req_payload = jmx_list_req_payload.to_json
        mbeanlist_json_response = post_no_auth("localhost", @jolokia_port, '/jolokia/', jmx_list_req_payload)
        mbean_category_names = mbeanlist_json_response["value"].keys
        collections = Set.new()
        mbean_category_names.each do |mbean_category_name|
            mbean_category_length = mbean_category_name.length

            if mbean_category_name.start_with? "solr/"
                core_name = mbean_category_name.slice(5, mbean_category_name.length-1)
                collection_name = core_name.slice(0, core_name.index("_shard"))
                if core_name.include? collection_name
                    collection_to_core_name_map[collection_name] = core_name
                end
                collections.add(collection_name)
            end
        end
        return collections, collection_to_core_name_map
    end

    def execute_solr_jmx_list_request_for_solr7()
        mbean_category_to_mbean_attr_map = Hash.new()
        collection_to_core_name_map = Hash.new()
        jmx_list_req_payload = {
            "type" => "list",
            "target" => {
                "url" => "service:jmx:rmi:///jndi/rmi://127.0.0.1:#{@solr_jmx_port}/jmxrmi"
            }
        }
        jmx_list_req_payload = jmx_list_req_payload.to_json
        mbeanlist_json_response = post_no_auth("localhost", @jolokia_port, '/jolokia/', jmx_list_req_payload)
        mbean_names = mbeanlist_json_response["value"]["solr"].keys
        collections = Set.new()

        mbean_names.each do |mbean_name, attrs_props_obj|
            if (mbean_name.start_with?("category=QUERY"))
                collection_name, core_name = get_collection_core_name(mbean_name)
                if (!collection_name.nil? && !collections.include?(collection_name))
                    collections.add(collection_name)
                end
                if (collection_to_core_name_map[collection_name].nil?)
                    collection_to_core_name_map[collection_name] = Array.new
                end
                if (!collection_to_core_name_map[collection_name].include?(core_name))
                    collection_to_core_name_map[collection_name].push(core_name)
                end
            end
        end

        return collections, collection_to_core_name_map
    end

    # Create bulk request for every mbean and every core based on the metric level.
    def create_solr_core_mbean_bulkrequest_and_mbeantype_list(metric_type_to_solr_core_mbean_attr_map, collection_name)
        solr_core_mbean_bulk_request = ''
        metric_type_to_mbean_type_obj = Hash.new()
        metric_type_to_solr_core_mbean_attr_map.each do |metric_aggr_type, mbean_attr_map|
            metric_type_to_mbean_type_obj[metric_aggr_type] = Array.new()
            mbean_attr_map.each do |mbean_name, mbean_attributes|
                solr_mbean_name = get_solr_core_mbean_name(mbean_name, collection_name)
                mbean_type = get_solr_core_mbean_type(mbean_name)
                metric_type_to_mbean_type_obj[metric_aggr_type].push(mbean_type)
                solr_core_mbean_request = {
                    "type" => "read",
                    "mbean" => "#{solr_mbean_name}",
                    "attribute" => "#{mbean_attributes}",
                    "target" => {
                        "url" => "service:jmx:rmi:///jndi/rmi://127.0.0.1:#{@solr_jmx_port}/jmxrmi"
                    }
                }
                solr_core_mbean_bulk_request = solr_core_mbean_bulk_request + "," + solr_core_mbean_request.to_json
            end
        end
        solr_core_mbean_bulk_request = "[" + solr_core_mbean_bulk_request.slice(1, solr_core_mbean_bulk_request.length) + "]"
        return solr_core_mbean_bulk_request, metric_type_to_mbean_type_obj
    end

    # Execute solr jmx read request for reading certain attributes.
    def execute_solr_core_jmx_read_request(solr_core_mbean_bulk_request, metric_type_to_mbean_type_obj, collection_name)
        solr_mbean_json_resp_obj = post_no_auth("localhost", @jolokia_port, '/jolokia/', solr_core_mbean_bulk_request)
        j = 0
        metric_type_to_mbean_type_obj.each do |metric_aggr_type, mbean_type_list|
            i = 0
            mbean_count = mbean_type_list.size
            until i >= mbean_count.to_i  do
                if solr_mbean_json_resp_obj[j]["status"] == 200
                    send_solr_jmx_metrics_to_metric_reporter(mbean_type_list[i], collection_name, metric_aggr_type, solr_mbean_json_resp_obj[j])
                else
                    puts "Status is not 200.. ERROR - #{solr_mbean_json_resp_obj[j]["stacktrace"]}"
                end
                i += 1
                j += 1
            end
        end
    end

    # Get solr complete mbean name based on solr version.
    def get_solr_core_mbean_name_for_solr7(mbean_name, collection_name)

        if collection_name != nil && !collection_name.empty?
            # Solr Mbean object name created by the  JMX reporter are hierarchical, dot-separated but also properly structured in JConsole.
            # This hierarchy consists of following elements : (registry name, reporter name, category, scope, name)
            # 1. registry name - It contains dot seperated registry names that the metrics will be shown under particular hierarchy.
            # Each domain part will be assigned to the dom variables. ex: dom1, dom2, ... domN properties in registry element.
            # 2. reporter - This element contains the reporter name i.e _jmx_
            solr_mbean_name = "solr:dom1=core,dom2=#{collection_name},dom3=*,dom4=*,#{mbean_name}"
        else
            solr_mbean_name = "solr:dom1=core,dom2=*,reporter=*jmx*,#{mbean_name}"
        end

        return solr_mbean_name
    end

    def get_solr_core_mbean_name_for_6x_below(mbean_name, collection_name)
        if solr_version_high()
            if collection_name != nil && !collection_name.empty?
                # Solr Mbean object name created by the  JMX reporter are hierarchical, dot-separated but also properly structured in JConsole.
                # This hierarchy consists of following elements : (registry name, reporter name, category, scope, name)
                # 1. registry name - It contains dot seperated registry names that the metrics will be shown under particular hierarchy.
                # Each domain part will be assigned to the dom variables. ex: dom1, dom2, ... domN properties in registry element.
                # 2. reporter - This element contains the reporter name i.e _jmx_
                solr_mbean_name = "solr:dom1=core,dom2=#{collection_name}*,reporter=_jmx_*,#{mbean_name}"
            else
                solr_mbean_name = "solr:dom1=core,dom2=*,reporter=*jmx*,#{mbean_name}"
            end
        else
            if collection_name != nil && !collection_name.empty?
                solr_mbean_name = "solr/#{collection_name}*:#{mbean_name}"
            else
                solr_mbean_name = "solr/*:#{mbean_name}"
            end
        end
        return solr_mbean_name
    end

    def get_solr_core_mbean_name(mbean_name, collection_name)
       if is_solr7?()
           return get_solr_core_mbean_name_for_solr7(mbean_name, collection_name)
       else
           return get_solr_core_mbean_name_for_6x_below(mbean_name, collection_name)
       end
    end


    # The mbean type is specified in 'scope' element from solr 6.4 version onwards and for lower versions in 'type' element.
    # This function returnn the solr mbean type for the given mbean name from that element based on the version.
    # ex1: solr 6.0 mbean : Value of mbean_name = type=/select,id=org.apache.solr.handler.component.SearchHandler (It returns the value of type element by removing the forward slash if it contains)
    # ex1: solr 6.4 mbean : Value of mbean_name = category=QUERY,scope=/select,name=org.apache.solr.handler.component.SearchHandler (It returns the value of scope element by removing the forward slash if it contains)
    def get_solr_core_mbean_type_for_solr6_lower(mbean_name)
        mbean_parts = mbean_name.split(",")
        mbean_type = nil
        if solr_version_high()
            mbean_parts.each do |mbean_part|
                if mbean_part.start_with? "scope="
                    mbean_type = mbean_part.slice(mbean_part.index("scope=")+6, mbean_part.length-1)
                    if mbean_type.start_with? "/"
                        mbean_type = mbean_type.slice(1,mbean_type.length-1)
                    end
                end
            end
        else
            mbean_parts.each do |mbean_part|
                if mbean_part.start_with? "type="
                    mbean_type = mbean_part.slice(mbean_part.index("type=")+5, mbean_part.length-1)
                    if mbean_type.start_with? "/"
                        mbean_type = mbean_type.slice(1,mbean_type.length-1)
                    end
                end
            end
        end
        return mbean_type
    end

    # The mbean names are of the format  category=QUERY,dom1=core,dom2=<collectionName>,dom3=<shardName>,dom4=<replicaName>,scope=/select,name=requestTimes
    # In the above case the above mbean is exposing the request times of the /select request handler for the given collection, replica
    # The mbean type is constructed using the scope and the name attributes, so in this case the mbean type will be select.requestTimes
    #
    def get_solr_core_mbean_type_for_solr7(mbean_name)

        mbean_parts = mbean_name.split(",")
        scope_value = nil
        name_value = nil

        mbean_parts.each do |mbean_part|
            if mbean_part.start_with? "scope="
                mbean_type = mbean_part.slice(mbean_part.index("scope=")+6, mbean_part.length-1)
                if mbean_type.start_with? "/"
                    scope_value = mbean_type.slice(1,mbean_type.length-1)
                else
                    scope_value = mbean_type
                end
            end

            if mbean_part.start_with? "name="
                mbean_type = mbean_part.slice(mbean_part.index("name=")+5, mbean_part.length-1)
                if mbean_type.start_with? "/"
                    name_value = mbean_type.slice(1,mbean_type.length-1)
                else
                    name_value = mbean_type
                end
            end
        end

        return scope_value + "." + name_value
    end

    def get_solr_core_mbean_type(mbean_name)
        if (is_solr7?())
            return get_solr_core_mbean_type_for_solr7(mbean_name)
        else
            return get_solr_core_mbean_type_for_solr6_lower(mbean_name)
        end
    end

    # Check if the given string is a float or not.
    def is_number? string
        true if Float(string) rescue false
    end

    # Parse the solr jmx mbean json response. Aggregate and push the metrics to medusa.
    def send_solr_jmx_metrics_to_metric_reporter(mbean_type, collection_name, metric_aggr_type, solr_mbean_json_resp_obj)
        # Some mbean types contains slash(/). All such slashes will be converted to '.' ex: admin/segments will be converted to admin.segments
        mbean_type = mbean_type.sub(/\//, '.')
        mbeans = solr_mbean_json_resp_obj["value"]
        mbean_names = mbeans.keys

        mbean_aggr_metric_map_obj = Hash.new()
        mbeans.each do |mbean_name, mbean_metrics|

            mbean_metrics.each do |metric_key, metric_value|
                metric_value_existed = mbean_aggr_metric_map_obj[metric_key]
                # When the node has multiple cores either for same collection or for different collection the value for the variable 'metric_value_existed' would exist from second core onwards.
                if metric_value_existed != nil
                    # When the variable 'metric_value_existed' existed the below if condition would execute and aggregates for all int/float metrics (like: 5minRateReqsPerSecond, 15minRateReqsPerSecond) 
                    # otherwise it would not aggregate and overwrite with the latest metric value. (ex: when fileds like version, source is passed in the code.)
                    if is_number?(mbean_aggr_metric_map_obj[metric_key])
                        mbean_aggr_metric_map_obj[metric_key] = metric_value.to_f + mbean_aggr_metric_map_obj[metric_key].to_f
                    else
                        if metric_value.to_s.include?("bytes")
                          metric_value = metric_value[/\d+/]
                          mbean_aggr_metric_map_obj[metric_key] = metric_value.to_f + mbean_aggr_metric_map_obj[metric_key].to_f
                        else
                          mbean_aggr_metric_map_obj[metric_key] = metric_value
                        end
                    end
                else
                  if metric_value.to_s.include?("bytes")
                    metric_value = metric_value[/\d+/]
                  end
                  mbean_aggr_metric_map_obj[metric_key] = metric_value
                end
            end
        end

        mbean_aggr_metric_map_obj.each do |metric_key, metric_agg_value|
            metric_key = metric_key.delete "\s\n"
            if metric_aggr_type == "add_aggr_metrics"

                fields = {"#{mbean_type}."+metric_key => metric_agg_value.to_s }

                # write metrics to medusa log (/opt/solr/log/jmx_medusa_stats.log)
                if (@medusa_log_writer != nil)
                    if collection_name != nil && !collection_name.empty?
                        @medusa_log_writer.write_medusa_log(collection_name, fields, @time)
                    else
                        @medusa_log_writer.write_medusa_log(MedusaLogWriter::CONST_CLUSTER_SUMMARY, fields, @time)
                    end
                end

                # Write the metrics to Graphite
                if (@graphite_writer != nil)
                    if collection_name != nil && !collection_name.empty?
                        @graphite_writer.write_collection_specific_metric("#{mbean_type}."+metric_key, GraphiteWriter::CONST_CORE_SUMMARY, metric_agg_value.to_s, @time, collection_name)
                    else
                        @graphite_writer.write_metric("#{mbean_type}."+metric_key, GraphiteWriter::CONST_CORE_SUMMARY, metric_agg_value.to_s, @time)
                    end
                end

            else
                metric_avg_aggr_value = metric_agg_value / mbean_names.size

                fields = {"#{mbean_type}."+metric_key => metric_avg_aggr_value.to_s}
                # write metrics to medusa log (/opt/solr/log/jmx_medusa_stats.log)
                if (@medusa_log_writer != nil)
                    if collection_name != nil && !collection_name.empty?
                        @medusa_log_writer.write_medusa_log(collection_name, fields, @time)
                    else
                        @medusa_log_writer.write_medusa_log(MedusaLogWriter::CONST_CLUSTER_SUMMARY, fields, @time)
                    end
                end

                # Write the metrics to Graphite
                if (@graphite_writer != nil)
                    if collection_name != nil && !collection_name.empty?
                        @graphite_writer.write_collection_specific_metric("#{mbean_type}."+metric_key, GraphiteWriter::CONST_CORE_SUMMARY, metric_avg_aggr_value.to_s, @time, collection_name)
                    else
                        @graphite_writer.write_metric("#{mbean_type}."+metric_key, GraphiteWriter::CONST_CORE_SUMMARY, metric_avg_aggr_value.to_s, @time)
                    end

                end

            end
        end
    end

    def get_collection_core_name(mbean_name)

        mbean_parts = mbean_name.split(",")
        mbean_type = nil
        collection_name = nil
        shard_name = nil
        replica_name = nil
        core_name = nil

        mbean_parts.each do |mbean_part|

            if (mbean_part.start_with?("dom2="))
                collection_name = mbean_part.slice(mbean_part.index("dom2=")+5, mbean_part.length-1)
            end

            if (mbean_part.start_with?("dom3="))
                shard_name = mbean_part.slice(mbean_part.index("dom3=")+5, mbean_part.length-1)
            end

            if (mbean_part.start_with?("dom4="))
                replica_name = mbean_part.slice(mbean_part.index("dom4=")+5, mbean_part.length-1)
            end

        end
        if (!collection_name.nil? && !shard_name.nil? && !replica_name.nil?)
            core_name = collection_name + "_" + shard_name + "_" + replica_name
        end

        return collection_name, core_name
    end

    # 6.4.0+ is considered as higher versions of solr
    def solr_version_high()
        if (@solr_version =~ /^[6-9]\.[4-9]/) || (@solr_version =~ /^[7-9]\.[0-3]/)
            return true
        else
            return false
        end
    end

    def is_solr7?()
        if (@solr_version =~ /^[7-9]\.[0-3]/)
            return true
        else
            return false
        end
    end
end



