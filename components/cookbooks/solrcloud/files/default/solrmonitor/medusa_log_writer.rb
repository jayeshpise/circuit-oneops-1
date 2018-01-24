class MedusaLogWriter

  attr_reader :name
  attr_writer :logger
  attr_accessor :fields

  CONST_CLUSTER_SUMMARY = 'solr_cluster_summary'

  def initialize(logger)
    @logger = logger
  end

  def write_medusa_log(name, fields, time = Time.now)
    @name = name
    @fields = fields
    @time = time
    fields_array = []
    @fields.each { |k, v| fields_array << "#{k}=#{v.nil? ? MISSING_FIELD_VALUE : v}" }
    # time is represented in Nano seconds based on the output example given by telegraf influxdb plugin README.md page.
    msg = "#{@name} #{fields_array.join(',')} #{@time.to_i}#{@time.usec}000"
    @logger.info(msg)
    msg
  end
end
