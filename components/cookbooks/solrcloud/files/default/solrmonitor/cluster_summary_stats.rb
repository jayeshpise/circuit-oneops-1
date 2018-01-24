require './medusa_log_writer'
require './graphite_writer'
require './rest_client'
require 'json'

class SolrClusterSummaryStats

  extend Solr::RestClient

  attr_accessor :collections, :cores, :select_avg_metrics, :update_avg_metrics, :get_avg_metrics,
                :update_handler_metrics, :filter_cache_metrics, :query_result_cache_metrics, :document_cache_metrics, :field_value_cache_metrics,
                :per_seg_filter_cache_metrics, :metrics_api, :merge_metrics

  @time
  @solr_version

  #Gather cluster statistics
  def self.get_stats(hostname, port, time, medusaLogWriter, graphiteWriter, solr_version, collections)

    @time = time
    @solr_version = solr_version
    begin

      # Get the list of collections from the LIST API
      @collections = collections

      solr_admin_metrics = nil
      # Metrics API is exposed only from Solr 6.4 onwards
      if (@solr_version =~ /[6-9]\.[4-9]/) || (@solr_version =~ /[7-9]\.[1-3]/)
        # Get the list of metrcis from the metrics API support from Solr 6.4 onwards
        solr_admin_metrics = get(hostname, port, '/solr/admin/metrics?group=all&type=all&wt=json')
      end

      # Get the Solr specific metrics
      # merges
      # commits
      # soft commits
      # segments
      # select/ get/ update metrics per collection
      solr_indexing_metrics(hostname, port, medusaLogWriter, solr_admin_metrics)

      if (solr_admin_metrics != nil)
        # Get the GC and Jetty Metrics from Metrics API
        gc_jetty_metrics(medusaLogWriter, solr_admin_metrics)
      end

    end

  end

  def self.solr_indexing_metrics(hostname, port, medusaLogWriter, solr_admin_metrics)

    # Get the list of cores
    core_list = get(hostname, port, '/solr/admin/cores?action=STATUS&wt=json')
    @cores = core_list["status"].keys

    @collections.each do |collection|

      number_of_cores_for_each_collection = 0
      select_total_response_time = 0
      select_total_timeouts = 0
      select_total_errors = 0
      select_total_5_min_rate_reqs = 0
      select_total_15_min_rate_reqs = 0
      select_total_requests_count = 0

      update_total_response_time = 0
      update_total_timeouts = 0
      update_total_errors = 0
      update_total_5_min_rate_reqs = 0
      update_total_15_min_rate_reqs = 0
      update_total_requests_count = 0

      get_total_response_time = 0
      get_total_timeouts = 0
      get_total_errors = 0
      get_total_5_min_rate_reqs = 0
      get_total_15_min_rate_reqs = 0
      get_total_requests_count = 0

      total_merges = 0
      total_commits = 0
      total_soft_autocommits = 0
      total_segments = 0

      total_filtercache_hits = 0
      total_filtercache_hitratio = 0
      total_filtercache_evictions = 0

      total_queryresultcache_hits = 0
      total_queryresultcache_hitratio = 0
      total_queryresultcache_evictions = 0

      total_documentcache_hits = 0
      total_documentcache_hitratio = 0
      total_documentcache_evictions = 0

      total_fieldvaluecache_hits = 0
      total_fieldvaluecache_hitratio = 0
      total_fieldvaluecache_evictions = 0

      total_persegfilter_hits = 0
      total_persegfilter_hitratio = 0
      total_persegfilter_evictions = 0

      @cores.each do |core|

        #Get the cores specific to this collection
        if core.include? collection

          number_of_cores_for_each_collection += 1

          # Total number of segments in this collection
          index = core_list["status"][core]["index"]
          total_segments += index["segmentCount"]

          # Get the MBeans data for the cores in a collection
          mbeans_metrics = get(hostname, port, "/solr/#{core}/admin/mbeans?wt=json&stats=true")

          solr_mbeans = mbeans_metrics["solr-mbeans"]

          solr_mbeans.each do |solr_mbean|

            # Get these metrics from admin/mbeans if solr version is less than 6.4 otherwise get it from metrics API
            if (@solr_version !~ /[6-9]\.[4-9]/) && (@solr_version !~ /[7-9]\.[1-3]/)
              # Select Stats
              if solr_mbean["/select"] != nil
                query_handler_select = solr_mbean["/select"]
                stats = query_handler_select["stats"]

                select_total_response_time += stats["95thPcRequestTime"]
                select_total_timeouts += stats["timeouts"]
                select_total_errors += stats["errors"]
                select_total_5_min_rate_reqs += stats["5minRateReqsPerSecond"]
                select_total_15_min_rate_reqs += stats["15minRateReqsPerSecond"]
                select_total_requests_count += stats["requests"]

              end

              # Update Stats
              if solr_mbean["/update"] != nil
                query_handler_update = solr_mbean["/update"]
                stats = query_handler_update["stats"]

                update_total_response_time += stats["95thPcRequestTime"]
                update_total_timeouts += stats["timeouts"]
                update_total_errors += stats["errors"]
                update_total_5_min_rate_reqs += stats["5minRateReqsPerSecond"]
                update_total_15_min_rate_reqs += stats["15minRateReqsPerSecond"]
                update_total_requests_count += stats["requests"]

              end

              # Get Stats
              if solr_mbean["/get"] != nil
                query_handler_get = solr_mbean["/get"]
                stats = query_handler_get["stats"]

                get_total_response_time += stats["95thPcRequestTime"]
                get_total_timeouts += stats["timeouts"]
                get_total_errors += stats["errors"]
                get_total_5_min_rate_reqs += stats["5minRateReqsPerSecond"]
                get_total_15_min_rate_reqs += stats["15minRateReqsPerSecond"]
                get_total_requests_count += stats["requests"]

              end

              # UpdateHandler Stats
              if solr_mbean["/updateHandler"] != nil
                update_handler = solr_mbean["/updateHandler"]
                stats = update_handler["stats"]

                total_commits += stats["commits"]
                total_soft_autocommits += stats["soft autocommits"]
              end
            end

            # FilterCache Stats
            if solr_mbean["/filterCache"] != nil
              filter_cache = solr_mbean["/filterCache"]
              stats = filter_cache["stats"]

              total_filtercache_hits += stats["hits"]
              total_filtercache_hitratio += stats["hitratio"]
              total_filtercache_evictions += stats["evictions"]
            end

            # queryResultCache Stats
            if solr_mbean["/queryResultCache"] != nil
              query_result_cache = solr_mbean["/queryResultCache"]
              stats = query_result_cache["stats"]

              total_queryresultcache_hits += stats["hits"]
              total_queryresultcache_hitratio += stats["hitratio"]
              total_queryresultcache_evictions += stats["evictions"]
            end

            # documentCache Stats
            if solr_mbean["/documentCache"] != nil
              document_cache = solr_mbean["/documentCache"]
              stats = document_cache["stats"]

              total_documentcache_hits += stats["hits"]
              total_documentcache_hitratio += stats["hitratio"]
              total_documentcache_evictions += stats["evictions"]
            end

            # fieldValueCache Stats
            if solr_mbean["/fieldValueCache"] != nil
              field_value_cache = solr_mbean["/fieldValueCache"]
              stats = field_value_cache["stats"]

              total_fieldvaluecache_hits += stats["hits"]
              total_fieldvaluecache_hitratio += stats["hitratio"]
              total_fieldvaluecache_evictions += stats["evictions"]
            end

            # perSegFilter Stats
            if solr_mbean["/perSegFilter"] != nil
              per_seg_filter_cache = solr_mbean["/perSegFilter"]
              stats = per_seg_filter_cache["stats"]

              total_persegfilter_hits += stats["hits"]
              total_persegfilter_hitratio += stats["hitratio"]
              total_persegfilter_evictions += stats["evictions"]
            end
          end
        end
      end

      @select_avg_metrics = { "select.response.time.95th" => {:metric => (select_total_response_time/number_of_cores_for_each_collection)},
                              "select.timeouts" => {:metric => select_total_timeouts},
                              "select.errors" => {:metric => select_total_errors},
                              "select.5minRateReqsPerSecond" => {:metric => select_total_5_min_rate_reqs},
                              "select.15minRateReqsPerSecond" => {:metric => select_total_15_min_rate_reqs},
                              "select.requests.count" => {:metric => select_total_requests_count}
      }

      @update_avg_metrics = { "update.response.time.95th" => {:metric => (update_total_response_time/number_of_cores_for_each_collection)},
                              "update.timeouts" => {:metric => update_total_timeouts},
                              "update.errors" => {:metric => update_total_errors},
                              "update.5minRateReqsPerSecond" => {:metric => update_total_5_min_rate_reqs},
                              "update.15minRateReqsPerSecond" => {:metric => update_total_15_min_rate_reqs},
                              "update.requests.count" => {:metric => update_total_requests_count}
      }

      @get_avg_metrics = { "get.response.time.95th" => {:metric => (get_total_response_time/number_of_cores_for_each_collection)},
                           "get.timeouts" => {:metric => get_total_timeouts},
                           "get.errors" => {:metric => get_total_errors.to_s},
                           "get.5minRateReqsPerSecond" => {:metric => get_total_5_min_rate_reqs},
                           "get.15minRateReqsPerSecond" => {:metric => get_total_15_min_rate_reqs},
                           "get.requests.count" => {:metric => get_total_requests_count}
      }

      @update_handler_metrics = { "commits" => {:metric => total_commits},
                                  "commits.soft" => {:metric => total_soft_autocommits},
                                  "total.segments" => {:metric => total_segments}
      }

      @filter_cache_metrics = { "cache.filterCache.hits" => {:metric => total_filtercache_hits},
                                "cache.filterCache.hitratio" => {:metric => total_filtercache_hitratio/number_of_cores_for_each_collection},
                                "cache.filterCache.evictions" => {:metric => total_filtercache_evictions}
      }

      @query_result_cache_metrics = { "cache.queryResultCache.hits" => {:metric => total_queryresultcache_hits},
                                      "cache.queryResultCache.hitratio" => {:metric => total_queryresultcache_hitratio/number_of_cores_for_each_collection},
                                      "cache.queryResultCache.evictions" => {:metric => total_queryresultcache_evictions}
      }

      @document_cache_metrics = { "cache.documentCache.hits" => {:metric => total_documentcache_hits},
                                  "cache.documentCache.hitratio" => {:metric => total_documentcache_hitratio/number_of_cores_for_each_collection},
                                  "cache.documentCache.evictions" => {:metric => total_documentcache_evictions}
      }

      @field_value_cache_metrics = { "cache.fieldValueCache.hits" => {:metric => total_fieldvaluecache_hits},
                                     "cache.fieldValueCache.hitratio" => {:metric => total_fieldvaluecache_hitratio/number_of_cores_for_each_collection},
                                     "cache.fieldValueCache.evictions" => {:metric => total_fieldvaluecache_evictions}
      }

      @per_seg_filter_cache_metrics = { "cache.perSegFilter.hits" => {:metric => total_persegfilter_hits},
                                        "cache.perSegFilter.hitratio" => {:metric => total_persegfilter_hitratio/number_of_cores_for_each_collection},
                                        "cache.perSegFilter.evictions" => {:metric => total_persegfilter_evictions}
      }

      #Do we want to stop writing average metrics for future solr versions?, why are we checking for all the existing solr versions?
      if (@solr_version.start_with? "4.") || (@solr_version.start_with? "5.") || (@solr_version.start_with? "6.3")
        write_metrics_to_medusa_log(@select_avg_metrics, medusaLogWriter, @time, collection)
        write_metrics_to_medusa_log(@update_avg_metrics, medusaLogWriter, @time, collection)
        write_metrics_to_medusa_log(@get_avg_metrics, medusaLogWriter, @time, collection)
        write_metrics_to_medusa_log(@update_handler_metrics, medusaLogWriter, @time, collection)
      end
      write_metrics_to_medusa_log(@filter_cache_metrics, medusaLogWriter, @time, collection)
      write_metrics_to_medusa_log(@query_result_cache_metrics, medusaLogWriter, @time, collection)
      write_metrics_to_medusa_log(@document_cache_metrics, medusaLogWriter, @time, collection)
      write_metrics_to_medusa_log(@field_value_cache_metrics, medusaLogWriter, @time, collection)
      write_metrics_to_medusa_log(@per_seg_filter_cache_metrics, medusaLogWriter, @time, collection)

      # If solr_version is 6.4 or above use the Metrics API to collect the core related metrics
      if solr_admin_metrics != nil
        parse_solr_admin_metrics(medusaLogWriter, collection, solr_admin_metrics)
      end

    end
  end

  def self.parse_solr_admin_metrics(medusaLogWriter, collection, solr_admin_metrics)

    number_of_cores_for_each_collection = 0
    select_total_response_time_p95_ms = 0
    select_total_timeouts = 0
    select_total_errors = 0
    select_total_client_errors = 0
    select_total_server_errors = 0
    select_total_5_min_rate_reqs = 0
    select_total_1_min_rate_reqs = 0
    select_total_requests_count = 0

    update_total_response_time_p95_ms = 0
    update_total_timeouts = 0
    update_total_errors = 0
    update_total_client_errors = 0
    update_total_server_errors = 0
    update_total_5_min_rate_reqs = 0
    update_total_1_min_rate_reqs = 0
    update_total_requests_count = 0

    get_total_response_time_p95_ms = 0
    get_total_timeouts = 0
    get_total_errors = 0
    get_total_client_errors = 0
    get_total_server_errors = 0
    get_total_5_min_rate_reqs = 0
    get_total_1_min_rate_reqs = 0
    get_total_requests_count = 0



    total_merges = 0
    total_commits = 0
    total_soft_autocommits = 0
    total_updateHandler_errors = 0
    total_segments = 0

    merge_errors = 0
    merge_major_count = 0
    merge_major_1_min_rate = 0
    merge_major_p95_ms = 0
    merge_major_p99_ms = 0
    merge_major_max_ms = 0
    merge_major_deletedDocs_count = 0
    merge_major_deletedDocs_1_min_rate = 0
    merge_major_docs_count = 0
    merge_major_docs_1min_rate = 0
    merge_major_running_oprtns = 0
    merge_major_running_docs = 0
    merge_major_running_segments = 0
    merge_minor_count = 0
    merge_minor_1minRate = 0
    merge_minor_p95_ms = 0
    merge_minor_p99_ms = 0
    merge_minor_max_ms = 0
    merge_minor_running_oprtns = 0
    merge_minor_running_docs = 0
    merge_minor_running_segments = 0
    is_merge_enabled = false

    metrics_keys = solr_admin_metrics["metrics"].keys
    metrics = solr_admin_metrics["metrics"]

    core_names = []
    metrics_keys.each do |metric_key|
      if metric_key.include? "solr.core"
        core_names.push(metric_key)
      end
    end

    core_names.each do |core_name|
      if core_name.include? collection

        number_of_cores_for_each_collection += 1
        # Get the statistics for each core associated with a particular collection

        # Get Select Metrics
        select_total_errors += metrics[core_name]["QUERY./select.errors"]["count"]
        select_total_client_errors += metrics[core_name]["QUERY./select.clientErrors"]["count"]
        select_total_5_min_rate_reqs += metrics[core_name]["QUERY./select.requestTimes"]["5minRate"]
        select_total_1_min_rate_reqs += metrics[core_name]["QUERY./select.requestTimes"]["1minRate"]
        select_total_response_time_p95_ms += metrics[core_name]["QUERY./select.requestTimes"]["p95_ms"]
        select_total_requests_count += metrics[core_name]["QUERY./select.requests"]["count"]
        select_total_server_errors += metrics[core_name]["QUERY./select.serverErrors"]["count"]
        select_total_timeouts += metrics[core_name]["QUERY./select.timeouts"]["count"]

        # Get Update Metrics for each core
        update_total_errors += metrics[core_name]["UPDATE./update.errors"]["count"]
        update_total_client_errors += metrics[core_name]["UPDATE./update.clientErrors"]["count"]
        update_total_5_min_rate_reqs += metrics[core_name]["UPDATE./update.requestTimes"]["5minRate"]
        update_total_1_min_rate_reqs += metrics[core_name]["UPDATE./update.requestTimes"]["1minRate"]
        update_total_response_time_p95_ms += metrics[core_name]["UPDATE./update.requestTimes"]["p95_ms"]
        update_total_requests_count += metrics[core_name]["UPDATE./update.requests"]["count"]
        update_total_server_errors += metrics[core_name]["UPDATE./update.serverErrors"]["count"]
        update_total_timeouts += metrics[core_name]["UPDATE./update.timeouts"]["count"]

        # Get Get Metrics for each core
        get_total_errors += metrics[core_name]["QUERY./get.errors"]["count"]
        get_total_client_errors += metrics[core_name]["QUERY./get.clientErrors"]["count"]
        get_total_5_min_rate_reqs += metrics[core_name]["QUERY./get.requestTimes"]["5minRate"]
        get_total_1_min_rate_reqs += metrics[core_name]["QUERY./get.requestTimes"]["1minRate"]
        get_total_response_time_p95_ms += metrics[core_name]["QUERY./get.requestTimes"]["p95_ms"]
        get_total_requests_count += metrics[core_name]["QUERY./get.requests"]["count"]
        get_total_server_errors += metrics[core_name]["QUERY./get.serverErrors"]["count"]
        get_total_timeouts += metrics[core_name]["QUERY./get.timeouts"]["count"]

        # Get merges, commits, segments etc from UPDATEHANDLER
        total_merges += metrics[core_name]["UPDATE.updateHandler.merges"]["count"]
        total_commits += metrics[core_name]["UPDATE.updateHandler.commits"]["count"]
        total_soft_autocommits += metrics[core_name]["UPDATE.updateHandler.softAutoCommits"]["value"]

        total_segments += metrics[core_name]["ADMIN./admin/segments.requests"]["count"]

        # Get the Merge metrics if exists
        # Merge metris are available if two boolean variables are set in solrconfig.xml
        # <bool name="mergeDetails">true</bool>
        # <bool name="directoryDetails">true</bool>
        unless metrics[core_name]["INDEX.merge.major"].nil?
          is_merge_enabled = true
          merge_errors += metrics[core_name]["INDEX.merge.errors"]["count"]
          merge_major_count += metrics[core_name]["INDEX.merge.major"]["count"]
          merge_major_1_min_rate += metrics[core_name]["INDEX.merge.major"]["1minRate"]
          merge_major_p95_ms += metrics[core_name]["INDEX.merge.major"]["p95_ms"]
          merge_major_p99_ms += metrics[core_name]["INDEX.merge.major"]["p99_ms"]
          merge_major_max_ms += metrics[core_name]["INDEX.merge.major"]["max_ms"]
          merge_major_deletedDocs_count += metrics[core_name]["INDEX.merge.major.deletedDocs"]["count"]
          merge_major_deletedDocs_1_min_rate += metrics[core_name]["INDEX.merge.major.deletedDocs"]["1minRate"]
          merge_major_docs_count += metrics[core_name]["INDEX.merge.major.docs"]["count"]
          merge_major_docs_1min_rate += metrics[core_name]["INDEX.merge.major.docs"]["1minRate"]
          merge_major_running_oprtns += metrics[core_name]["INDEX.merge.major.running"]["value"]
          merge_major_running_docs += metrics[core_name]["INDEX.merge.major.running.docs"]["value"]
          merge_major_running_segments += metrics[core_name]["INDEX.merge.major.running.segments"]["value"]
          merge_minor_count += metrics[core_name]["INDEX.merge.minor"]["count"]
          merge_minor_1minRate += metrics[core_name]["INDEX.merge.minor"]["1minRate"]
          merge_minor_p95_ms += metrics[core_name]["INDEX.merge.minor"]["p95_ms"]
          merge_minor_p99_ms += metrics[core_name]["INDEX.merge.minor"]["p99_ms"]
          merge_minor_max_ms += metrics[core_name]["INDEX.merge.minor"]["max_ms"]
          merge_minor_running_oprtns += metrics[core_name]["INDEX.merge.minor.running"]["value"]
          merge_minor_running_docs += metrics[core_name]["INDEX.merge.minor.running.docs"]["value"]
          merge_minor_running_segments += metrics[core_name]["INDEX.merge.minor.running.segments"]["value"]
        end
      end
    end

    @metrics_api = { "select.response.time.95thpc" => {:metric => (select_total_response_time_p95_ms/number_of_cores_for_each_collection)},
                     "select.timeouts" => {:metric => select_total_timeouts},
                     "select.errors" => {:metric => select_total_errors},
                     "select.errors.client" => {:metric => select_total_client_errors},
                     "select.errors.server" => {:metric => select_total_server_errors},
                     "select.5minRateReqsPerSecond" => {:metric => select_total_5_min_rate_reqs},
                     "select.1minRateReqsPerSecond" => {:metric => select_total_1_min_rate_reqs},
                     "select.requests.count" => {:metric => select_total_requests_count},
                     "update.response.time.95th" => {:metric => (update_total_response_time_p95_ms/number_of_cores_for_each_collection)},
                     "update.timeouts" => {:metric => update_total_timeouts},
                     "update.errors" => {:metric => update_total_errors},
                     "update.errors.client" => {:metric => update_total_client_errors},
                     "update.errors.server" => {:metric => update_total_server_errors},
                     "update.5minRateReqsPerSecond" => {:metric => update_total_5_min_rate_reqs},
                     "update.1minRateReqsPerSecond" => {:metric => update_total_1_min_rate_reqs},
                     "update.requests.count" => {:metric => update_total_requests_count},
                     "get.response.time.95th" => {:metric => (get_total_response_time_p95_ms/number_of_cores_for_each_collection)},
                     "get.timeouts" => {:metric => get_total_timeouts},
                     "get.errors" => {:metric => get_total_errors.to_s},
                     "get.errors.client" => {:metric => get_total_client_errors},
                     "get.errors.server" => {:metric => get_total_server_errors},
                     "get.5minRateReqsPerSecond" => {:metric => get_total_5_min_rate_reqs},
                     "get.1minRateReqsPerSecond" => {:metric => get_total_1_min_rate_reqs},
                     "get.requests.count" => {:metric => get_total_requests_count},
                     "merges" => {:metric => total_merges},
                     "commits" => {:metric => total_commits},
                     "commits.soft" => {:metric => total_soft_autocommits},
                     "total.segments" => {:metric => total_segments}
    }
    write_metrics_to_medusa_log(@metrics_api, medusaLogWriter, @time, collection)

    if (is_merge_enabled)
      @merge_metrics = { "merge.errors" => {:metric => merge_errors},
                         "merge.major.count" => {:metric => merge_major_count},
                         "merge.major.1minRate" => {:metric => merge_major_1_min_rate},
                         "merge.major.p95_ms" => {:metric => merge_major_p95_ms/number_of_cores_for_each_collection},
                         "merge.major.p99_ms" => {:metric => merge_major_p99_ms/number_of_cores_for_each_collection},
                         "merge.major.max_ms" => {:metric => merge_major_max_ms/number_of_cores_for_each_collection},
                         "merge.major.deletedDocs.count" => {:metric => merge_major_deletedDocs_count},
                         "merge.major.deletedDocs.1minRate" => {:metric => merge_major_deletedDocs_1_min_rate},
                         "merge.major.docs.count" => {:metric => merge_major_docs_count},
                         "merge.major.docs.1minRate" => {:metric => merge_major_docs_1min_rate},
                         "merge.major.running.operations" => {:metric => merge_major_running_oprtns},
                         "merge.major.running.docs" => {:metric => merge_major_running_docs},
                         "merge.major.running.segments" => {:metric => merge_major_running_segments},
                         "merge.minor.count" => {:metric => merge_minor_count},
                         "merge.minor.1minRate" => {:metric => merge_minor_1minRate},
                         "merge.minor.p95_ms" => {:metric => merge_minor_p95_ms/number_of_cores_for_each_collection},
                         "merge.minor.p99_ms" => {:metric => merge_minor_p99_ms/number_of_cores_for_each_collection},
                         "merge.minor.max_ms" => {:metric => merge_minor_max_ms/number_of_cores_for_each_collection},
                         "merge.minor.running.operations" => {:metric => merge_minor_running_oprtns},
                         "merge.minor.running.docs" => {:metric => merge_minor_running_docs},
                         "merge.minor.running.segments" => {:metric => merge_minor_running_segments}
      }
      write_metrics_to_medusa_log(@merge_metrics, medusaLogWriter, @time, collection)
    end
  end

  def self.gc_jetty_metrics(medusaLogWriter, solr_admin_metrics)

    metrics = solr_admin_metrics["metrics"]

    gc_metrics = {
        "gc.oldgen.count" => {:metric => metrics["solr.jvm"]["gc.G1-Old-Generation.count"]["value"]},
        "gc.oldgen.time" => {:metric => metrics["solr.jvm"]["gc.G1-Old-Generation.time"]["value"]},
        "gc.younggen.count" => {:metric => metrics["solr.jvm"]["gc.G1-Young-Generation.count"]["value"]},
        "gc.younggen.time" => {:metric => metrics["solr.jvm"]["gc.G1-Young-Generation.time"]["value"]},
    }

    jetty_metrics = {
        "jetty.active.requests.count" => {:metric => metrics["solr.jetty"]["org.eclipse.jetty.server.handler.DefaultHandler.active-requests"]["count"]},
        "jetty.connect.requests.count" => {:metric => metrics["solr.jetty"]["org.eclipse.jetty.server.handler.DefaultHandler.connect-requests"]["count"]},
        "jetty.connect.requests.1min.rate" => {:metric => metrics["solr.jetty"]["org.eclipse.jetty.server.handler.DefaultHandler.connect-requests"]["1minRate"]}
    }

    write_to_medusa_log(gc_metrics, medusaLogWriter)
    write_to_medusa_log(jetty_metrics, medusaLogWriter)

  end

  def self.write_to_medusa_log(metrics, medusaLogWriter)
    if (medusaLogWriter != nil)
      metrics.each { |key, metric|
        # cluster level summary stats
        fields = {key => metric[:metric].to_s}
        medusaLogWriter.write_medusa_log(MedusaLogWriter::CONST_CLUSTER_SUMMARY, fields, @time)
      }
    end
  end

  def self.write_metrics_to_medusa_log(metrics, medusaLogWriter, time, collection)
    if (medusaLogWriter != nil)
      metrics.each { |key, metric|
        # cluster level summary stats
        fields = {key => metric[:metric].to_s}
        if (collection != nil && !collection.empty?)
          medusaLogWriter.write_medusa_log(collection, fields, time)
        else
          medusaLogWriter.write_medusa_log(MedusaLogWriter::CONST_CLUSTER_SUMMARY, fields, time)
        end
      }
    end
  end

end