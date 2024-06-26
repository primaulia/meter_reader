require 'csv'
require 'pry-byebug'

class MeterReader
  NMI_PATTERN = /^200,(?<nmi>\w+),\w+,(\w+)?,(?<nmi_suffix>\w+),(\w+)?,\w+,(?<current_consumption_unit>\w+),(?<interval_length>\d+),(\w+)?$/

  attr_reader :sql_statements_by_nmi

  def initialize(filepath)
    @filepath = filepath
    @current_meter = {}
    @sql_statements_by_nmi = {}
    @file_validator = %w[900 100] # works like a stack. the file is valid if it starts with 100 record and ends with 900 record

    parse_file
  end

  def call
    raise StandardError, "Data is invalid" unless file_valid?

    flattened_sql_statements
  end

  private

  def parse_file
    File.read(@filepath).each_line do |line|
      line = line.strip
      validate(line) if line.start_with?('100') || line.start_with?('900')
      @current_meter = process_nmi_record(line) if line.start_with?('200')

      if can_process_interval_record?(line)
        interval_record = process_interval_record(line)
        prepare_sql_statements(interval_record)
      end
    end
  end

  def process_nmi_record(line)
    match_groups = line.match(NMI_PATTERN)
    raise ArgumentError, "NMI 200 record is invalid" if match_groups.nil?

    {
      nmi: match_groups[:nmi],
      unit: match_groups[:current_consumption_unit].downcase,
      interval_length: match_groups[:interval_length].to_i,
      nmi_suffix: match_groups[:nmi_suffix].downcase
    }
  end

  def process_interval_record(line)
    raise ArgumentError, "NMI 300 record is invalid" unless valid_record?(line)

    parts = line.chomp.split(',')

    {
      time: prepare_timestamp(parts[1]),
      consumption_values: parts[2...last_interval_index].map(&:to_f)
    }
  end

  def prepare_sql_statements(interval_record)
    consumption_values = interval_record[:consumption_values]
    time = interval_record[:time]
    @sql_statements_by_nmi[current_nmi] ||= {}

    if @sql_statements_by_nmi[current_nmi].empty? || @sql_statements_by_nmi[current_nmi][time].nil?
      @sql_statements_by_nmi[current_nmi][time] = transform_values_to_statements(consumption_values, time)
    else
      @sql_statements_by_nmi[current_nmi][time] = merge_values_to_existing_statements(consumption_values, time)
    end
  end

  def transform_values_to_statements(consumption_values, time)
    consumption_values.map do |value|
      statement = "INSERT INTO meter_readings ('nmi', 'timestamp', 'consumption') VALUES ('#{current_nmi}', '#{time}', #{value});"
      time += current_interval_length * 60
      statement
    end
  end

  def merge_values_to_existing_statements(consumption_values, time)
    @sql_statements_by_nmi[current_nmi][time].map.with_index do |statement, index|
      meter_reading_pattern = /,\s(\d+\.?\d*)/
      inserted_value = statement.match(meter_reading_pattern)[1].to_f
      new_value = inserted_value + consumption_values[index] # assumed that each repeated NMI data will have the same interval length
      statement = statement.gsub(meter_reading_pattern, ", #{new_value}")
      statement
    end
  end

  def flattened_sql_statements
    @sql_statements_by_nmi.values.flat_map(&:values).flatten
  end

  def validate(line)
    @file_validator.pop if line.start_with?('100') && @file_validator.last == '100'
    @file_validator.pop if line.start_with?('900') && @file_validator.last == '900'
  end

  def file_valid?
    @file_validator.empty?
  end

  def valid_record_size
    1440 / current_interval_length
  end

  def valid_record?(record)
    record.match?(/^300,(\d+)(,\d+\.?\d*){#{valid_record_size}},.*$/)
  end

  def current_nmi
    @current_meter[:nmi]
  end

  def current_consumption_unit
    @current_meter[:unit]
  end

  def current_suffix
    @current_meter[:nmi_suffix]
  end

  def current_interval_length
    @current_meter[:interval_length]
  end

  # only process line if it passes this condition
  # - is a 300 record
  # - have current_nmi state, set up
  # - the unit we worked with is in Watt Hour format (active consumption)
  # - export data only (nmi suffix E1 or E2)
  def can_process_interval_record?(line)
    line.start_with?('300') && current_nmi && current_consumption_unit.include?('wh') && current_suffix.include?("e")
  end

  def last_interval_index
    valid_record_size + 2
  end

  def convert_to_kwh(value)
    raise ArgumentError if value.class != Integer

    case current_consumption_unit
    when 'mwh' then value * 1000
    when 'wh' then value.to_f / 1000
    when 'kwh' then value
    else
      raise StandardError, 'Invalid unit of measurement'
    end
  end

  def prepare_timestamp(interval_date)
    date = Date.parse(interval_date)
    Time.new(date.year, date.month, date.day, 0, current_interval_length, 0) # the initial timestamp will be at the end of the interval length
  end
end

# HOW TO TEST - uncomment the line below to test
# statements = MeterReader.new('fixtures/sample1.csv').call
# binding.pry
# p statements
