require 'csv'
require 'pry-byebug'

class MeterReaderMaker
  NMI_PATTERN = /^200,(?<nmi>\w+),\w+,(\w+)?,(?<nmi_suffix>\w+),(\w+)?,\w+,(?<consumption_unit>\w+),(?<interval_length>\d+),(\w+)?$/

  def initialize(filepath)
    @filepath = filepath
    @current_nmi = ""
    @sql_statements = {}
    @consumption_unit = ""
    @file_validator = %w[900 100] # works like a stack. the file is valid if it starts with 100 record and ends with 900 record

    parse_file
  end

  def call
    raise ArgumentError, "Data is invalid" unless data_valid?

    @sql_statements
  end

  private

  def parse_file
    File.read(@filepath).each_line do |line|
      validate(line) if line.start_with?('100') || line.start_with?('900')
      process_nmi_record(line) if line.start_with?('200')
      process_interval_records(line) if can_process_line?(line)
    end

    merge_sql_statements
  end

  def process_nmi_record(line)
    match_groups = line.match(NMI_PATTERN)
    @current_nmi = match_groups[:nmi]
    @consumption_unit = match_groups[:consumption_unit].downcase
    @interval_length = match_groups[:interval_length].to_i # 5, 15, 30 minutes
    @suffix = match_groups[:nmi_suffix].downcase
  end

  def process_interval_records(line)
    parts = line.chomp.split(',')
    time = prepare_timestamp(parts[1])
    consumption_values = parts[2...last_interval_index].map(&:to_f)

    @sql_statements[@current_nmi] ||= []

    if @sql_statements[@current_nmi].empty?
      @sql_statements[@current_nmi] = transform_values_to_statements(consumption_values, time)
    else
      @sql_statements[@current_nmi] = merge_values_to_existing_statements(consumption_values)
    end
  end

  def transform_values_to_statements(consumption_values, time)
    consumption_values.map do |value|
      statement = "INSERT INTO meter_readings ('nmi', 'timestamp', 'consumption') VALUES ('#{@current_nmi}', '#{time}', #{value});"
      time += @interval_length * 60
      statement
    end
  end

  def merge_values_to_existing_statements(consumption_values)
    @sql_statements[@current_nmi].map.with_index do |statement, index|
      pattern = /,\s(\d+\.?\d*)/
      inserted_value = statement.match(pattern)[1].to_f
      new_value = inserted_value + consumption_values[index]
      statement = statement.gsub(pattern, ", #{new_value}")
      statement
    end
  end

  def merge_sql_statements
    flattened_array = []
    @sql_statements.each_value do |value|
      flattened_array.concat(value.flatten)
    end
    @sql_statements = flattened_array
  end

  def validate(line)
    @file_validator.pop if line.start_with?('100') && @file_validator.last == '100'
    @file_validator.pop if line.start_with?('900') && @file_validator.last == '900'
  end

  def data_valid?
    @file_validator.empty?
  end

  # only process line if it passes this condition
  # - is a 300 record
  # - have @current_nmi state, set up
  # - the unit we worked with is in Watt Hour format (active consumption)
  # - export data only (nmi suffix E1 or E2)
  def can_process_line?(line)
    line.start_with?('300') && @current_nmi && @consumption_unit.include?('wh') && @suffix.include?("e")
  end

  def last_interval_index
    (1440 / @interval_length) + 2
  end

  def convert_to_kwh(value)
    case @consumption_unit
    when 'MWh' then value * 1000
    when 'Wh' then value.to_f / 1000
    end
  end

  def prepare_timestamp(interval_date)
    date = Date.parse(interval_date)
    Time.new(date.year, date.month, date.day, 0, @interval_length, 0) # the initial timestamp will be at the end of the interval length
  end
end

statements = MeterReaderMaker.new("./fixtures/sample1.csv").call
binding.pry
p statements
