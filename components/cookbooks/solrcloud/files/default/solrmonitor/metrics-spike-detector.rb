require 'rubygems'
require 'fileutils'
require 'json'

# This class has logic to detect the list of metrics which have spiked together.  It writes all the spiked metrics in the JSON format to a
# file named spiked-metrics.json file.  It keeps track of the metrics observed in the last 10 minute window.  It considers a metric has spiked if its value is
# deviated from the last 10 minute average value of the metric by a configured spike threshold value
#
# The metrics.log.1 has the most recent metric capture, metrics.log.2 the next recent and so on up to metrics.log.10
#

class SpikeDetector

  # fully qualified file name of the metrics log file in which metrics will be emitted
  @metrics_file

  # The Spike reporter implementation which will emit the metrics which spiked together, currently it emits to a file
  # In future we can even send this to Solr/Elastic/Splunk server for searches
  @spike_reporter

  # The fully qualified file name into which the spiked metrics data will be written
  @spiked_metrics_file

  # The full qualified properties file for customizing the spike threshold values for individual metrics
  # If the threshold value is not customized for a metric it will use the default threshold value
  @spiked_metrics_property_file

  @spiked_metrics_threshold_props


  def initialize(metrics_file, spiked_metrics_file)
    @metrics_file = metrics_file
    @spiked_metrics_file = spiked_metrics_file
    @spike_reporter = FileMetricsSpikeReporter.new(@spiked_metrics_file)
    @spiked_metrics_property_file = "spiked-metrics.properties"

    @spiked_metrics_threshold_props = get_spike_threshold_config()

  end

  # Capture the current metrics to the a metrics log file
  def capture_metrics
    # The -test option is required as we just would like to spit out the current value of the metrics once and terminate the process.
    # If the -test option is not provided, the telegraf process will run in the foreground in-definitely spitting out metrics every minute or so
    `/usr/bin/telegraf --config /etc/telegraf/telegraf.conf -test -quiet > #{@metrics_file}`
  end

  # This method computes the set of metrics which have spiked above the configured threshold value
  # It computes the average of the metric values in the last 10 minute window and compares this average value with the
  # current metric value. If the difference is more than the configured spike_threshold value then it considers this metric has
  # spiked. All the list of spiked metrics are written to the file

  def detect_spikes

    metrics_spiked = Array.new

    capture_metrics()
    avg_metrics = compute_avg_metric_last10_minutes()
    curr_metrics, timestamp = compute_current_metrics()


    if (avg_metrics.size() > 0)

      curr_metrics.each do |metric, curr_value|

        percent_spike = 0
        if (avg_metrics[metric] != nil)

           # We are only interested in deviation so negative spikes are also considered
           spike = (curr_value - avg_metrics[metric]).abs()

           if (avg_metrics[metric] > 0)
             percent_spike = (spike / avg_metrics[metric]) * 100
           end

           if (@spiked_metrics_threshold_props[metric].nil?)
             # If spike threshold is not overridden then we fall to the default threshold value
             spike_threshold = @spiked_metrics_threshold_props["default"]
           else
             spike_threshold = @spiked_metrics_threshold_props[metric]
           end

           if  (percent_spike.abs() > spike_threshold)
                # puts "Spike detected in metric #{metric}"
                # puts "Percent Spike: #{percent_spike} for metric #{metric}"
                metric_spike_obj = {
                    "metric" => metric,
                    "curr_value" => curr_value,
                    "avg_value" => avg_metrics[metric],
                    "percent_spike" => percent_spike.ceil()
                }
             metrics_spiked.push(metric_spike_obj)
           end
        end
      end

    end


    if (metrics_spiked.size() > 0)
      spiked_metrics_data = { "timestamp" => Time.now(), "spiked_metrics" => metrics_spiked}
      @spike_reporter.report_spiked_metrics(spiked_metrics_data)
    end

    # rotate the log file
    LogRotator.rotate_logs(@metrics_file, 10)

  end

  def compute_current_metrics()
    metric_file_reader = MetricFileReader.new(@metrics_file)
    metric_file_reader.parse()
    curr_metrics = metric_file_reader.metrics
    return curr_metrics, metric_file_reader.timestamp
  end

  def compute_avg_metric_last10_minutes()

      metrics_arr = Array.new()
      avg_metrics = Hash.new()

      # Read the metrics captured in the last 10 minutes from the respective metric log files
      # The metrics captured in the last 10 minute windows are in log files @metric_file.[1..10]
      # The default value of @metric_file is metrics.log which means the last 10 minutes metric log files
      # are metrics.log.1, metrics.log.2 ...............metrics.log.10.  The most recent capture metric is
      # in metric.log.10

      total_log_files = 0
      for number in (1..10)
         metrics_log_file = @metrics_file + "." + number.to_s
         if (File.exists?(metrics_log_file))
           file_reader = MetricFileReader.new(metrics_log_file)
           file_reader.parse()
           metrics_arr.push(file_reader.metrics)
           total_log_files+=1
         end
      end


      if (metrics_arr.length > 0)
        # metrics captured in the first log file
        metrics = metrics_arr[0]

        metrics.each do |metric, value|
          # Iterate through each log file and compute the average value for each metric
          metrics_arr.each do |metric_hash|
            if (metric_hash.has_key?(metric))
              if (avg_metrics[metric].nil?)
                avg_metrics[metric] = 0.0
              end
              avg_metrics[metric] += metric_hash[metric]
            end
          end
        end

        avg_metrics.each do |metric, value|
          if (total_log_files > 0)
            avg_metrics[metric] /= total_log_files
          end

        end
      end
      return avg_metrics
  end

  def get_spike_threshold_config()

    props = Hash.new()

    if (File.exists?(@spiked_metrics_property_file))

      File.open(@spiked_metrics_property_file, "r").each_line() do |line|

        if (line.start_with?("#"))
          continue
        end

        tokens = line.split("=")
        metric_name = tokens[0]
        spike_threshold = tokens[1].chop!().to_i()

        #strip the prefix "percent."
        metric_name = metric_name["threshold.percent.".length()..metric_name.length()]

        props[metric_name] = spike_threshold

      end

      if (props["default"].nil?)
        props["default"] = 30
      end

    else
      props["default"] = 30
    end

    return props

  end


end

# This class reads all the metrics logged into the metrics log file
# It uses the LineProtocolParser to parse the each line to extract the metric values
#
class MetricFileReader
   @metric_file
   @metrics
   @timestamp

   attr_reader :metrics, :tags, :level1, :level2, :timestamp

   def initialize(metric_file)
     @metric_file = metric_file
     @metrics = Hash.new
   end

   def parse()
     File.open(@metric_file).each do |line|
       metrics_record = LineProtocolParser.parse_metrics(line)
       if (metrics_record != nil)
          @metrics.merge!(metrics_record["metrics"])
         @timestamp = metrics_record["timestamp"]
       end
     end
   end

end


#
# This class parses a metric line in the influx Db line protocol format
# The influxDB line protocol emits the metrics in the following format
# > level1,level2,tag1=value1,tag2=value2....  metric1=value1,metric2=value2... timestamp
# Sample metric line
# > cpu,cpu=cpu0,host=solrcloud-556365-1-41414541 usage_guest=0,usage_guest_nice=0,usage_idle=100,usage_iowait=0,usage_irq=0,usage_nice=0,usage_softirq=0,usage_steal=0,usage_system=0,usage_user=0 1513706342000000000
#
class LineProtocolParser

  def self.parse_metrics(metric_line)

    if (metric_line.include?("Plugin:"))
      # We want to skip the Plugin lines as it is just an info that the metrics following are emitted by this plugin
      # We do not care for this information
      return;
    end

    if (metric_line.include?("Error handling response:"))
      # This messages just mean that telegraf was not able to retrieve the metrics via the configured plugins
      # We just ingore these messages for this script purpose
      return
    end


    # The top most logical parts of the metric line i.e level ands tags, metrics, timestamp are separated by a space character
    tokens = metric_line.split(' ')
    #tokens[0] has the > character which we ignore
    levels_and_tags = tokens[1]
    metrics = tokens[2]
    timestamp = tokens[3]

    tokens = levels_and_tags.split(',')

    start_tag_index = 0
    if (!tokens[0].include? "=")
      level1 = tokens[0]
      start_tag_index = 1
    end

    if (!tokens[1].include? "=")
      level2 = tokens[1]
      start_tag_index = 2

    end

    len = tokens.length
    tags = tokens[start_tag_index..len]

    tags = Array.new
    for tag in tags
      tag_value_pair = tag.split("=")
      tags.push({ "name" => tag_value_pair[0], "value" => tag_value_pair[1] })
    end

    tokens = metrics.split(",")
    metrics_map = Hash.new

    for token in tokens
      metric_value_pairs = token.split("=")
      metric_name = level1.to_s + "-" + level2.to_s + "-" + metric_value_pairs[0]
      metrics_map[metric_name] = metric_value_pairs[1].to_f
    end

    return {
        "level1" => level1,
        "level2" => level2,
        "tags" => tags,
        "metrics" => metrics_map,
        "timestamp" => timestamp
    }
  end

end


class FileMetricsSpikeReporter

  @spike_metrics_file

  def initialize(spike_metrics_file)
    @spike_metrics_file = spike_metrics_file
  end

  def report_spiked_metrics(spiked_metrics)

      spike_metrics_json = JSON.pretty_generate(spiked_metrics)
      File.open(@spike_metrics_file, 'w') { |file| file.write(spike_metrics_json) }
      LogRotator.rotate_logs(@spike_metrics_file, 30)

  end

end

class LogRotator

  def self.rotate_logs(metrics_file, num_logs_to_keep)

    log_num = (num_logs_to_keep.to_i - 1)
    for number in (log_num).downto(1) do
      src_file = metrics_file + "." + number.to_s
      target_log_num = (number.to_i + 1)
      dest_file = metrics_file + "." + target_log_num.to_s

      if (File.exist?(src_file))
        FileUtils.move(src_file, dest_file)
      end

    end
    # puts "Rotating current metrics log file to metrics.log.10"
    FileUtils.move(metrics_file, metrics_file + "." + 1.to_s)
  end

end


metrics_file = "/opt/solr/solrmonitor/spiked-metrics/metrics.log"
spiked_metrics_file = "/opt/solr/solrmonitor/spiked-metrics/spiked-metrics.json"

spike_detector = SpikeDetector.new(metrics_file, spiked_metrics_file)
spike_detector.detect_spikes()






