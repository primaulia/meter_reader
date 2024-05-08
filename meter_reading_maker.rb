require 'csv'
require 'pry-byebug'

class MeterReaderMaker
  NMI_PATTERN = /^200,(\w+)(,.*?){5},(\w+),.*$/

  def initialize(filepath)
    @filepath = filepath
    @current_nmi = ""
    @sql_statements = []
    @consumption_unit = ""
    @file_validator = %w[900 100] # works like a stack. the file is valid if it starts with 100 record and ends with 900 record

    parse_file
  end

  def call
    @sql_statements if data_valid?
  end

  private

  def parse_file
    File.read(@filepath).each_line do |line|
      validate(line) if line.start_with?('100') || if line.start_with?('900')

      if line.start_with?('200')
        @current_nmi = line.match(NMI_PATTERN)[1]
        @consumption_unit = line.match(NMI_PATTERN)[3]
      end

      update_consumption_values(line) if can_process_line?(line)
    end
  end

  def update_consumption_values(line)
    parts = line.chomp.split(',')
    interval_date = parts[1]
    consumption_values = parts[2...50].map(&:to_f)

    date = Date.parse(interval_date)
    time = Time.new(date.year, date.month, date.day, 0, 30, 0)

    consumption_values.each do |value|
      timestamp = time.strftime("%Y-%m-%d %H:%M")

      @sql_statements << "INSERT INTO meter_readings ('nmi', 'timestamp', 'consumption') VALUES ('#{@current_nmi}', '#{timestamp}', #{value});"

      time += 30 * 60
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
  def can_process_line?(line)
    line.start_with?('300') && @current_nmi && @consumption_unit == 'kWh'
  end
end

statements = MeterReaderMaker.new("./fixtures/sample1.csv").call
binding.pry
p statements
