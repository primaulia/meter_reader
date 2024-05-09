require 'csv'
require 'pry-byebug'

class MeterReaderMaker
  NMI_PATTERN = /^200,(?<nmi>\w+),\w+,(\w+)?,(?<nmi_suffix>\w+),(\w+)?,\w+,(?<consumption_unit>\w+),(?<interval_length>\d+),(\w+)?$/

  def initialize(filepath)
    @filepath = filepath
    @current_nmi = ""
    @sql_statements = []
    @consumption_unit = ""
    @consumption_data = {}
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

      if line.start_with?('200')
        match_groups = line.match(NMI_PATTERN)
        @current_nmi = match_groups[:nmi]
        @consumption_unit = match_groups[:consumption_unit].downcase
        @interval_length = match_groups[:interval_length].to_i # 5, 15, 30 minutes
        @suffix = match_groups[:nmi_suffix].downcase
      end

      update_consumption_values(line) if can_process_line?(line)
    end

    prepare_sql_statements
  end

  def update_consumption_values(line)
    parts = line.chomp.split(',')
    interval_date = parts[1]
    consumption_values = parts[2...last_interval_index].map(&:to_f)

    @consumption_data[@current_nmi] ||= {}
    @consumption_data[@current_nmi][interval_date] ||= {}
    @consumption_data[@current_nmi][interval_date][:values] ||= []
    @consumption_data[@current_nmi][interval_date][:values] << consumption_values
    @consumption_data[@current_nmi][interval_date][:unit] = @consumption_unit
  end

  def prepare_sql_statements
    current_consumption = @consumption_data[@current_nmi]
    current_consumption.each do |interval_date, data|
      time = prepare_timestamp(interval_date)
      summed_values = data[:values].transpose.map { |sub_array| sub_array.sum }
      summed_values.each do |value|
        timestamp = time.strftime("%Y-%m-%d %H:%M")
        value = convert_to_kwh(value) if data[:unit] != 'kwh'
        @sql_statements << "INSERT INTO meter_readings ('nmi', 'timestamp', 'consumption') VALUES ('#{@current_nmi}', '#{timestamp}', #{value});"

        time += @interval_length * 60
      end
    end
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
  # - export data only
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
