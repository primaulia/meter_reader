require 'csv'
require 'pry-byebug'

class MeterReaderMaker
  def initialize(filepath)
    @filepath = filepath
    @sql_queries = []
    @current_nmi = ""
    @consumption_data = {}
    @sql_statements = []

    parse_csv

  end

  def call
    create_statements
  end

  private

  def parse_csv
    CSV.foreach(@filepath) do |row|
      record_indicator = row.first.to_i

      case record_indicator
      when 100 then handle_header
      when 200 then handle_nmi_data(row)
      when 300 then handle_interval(row) && @current_nmi
      when 400 then puts "interval event"
      when 500 then puts "b2b"
      when 900 then puts "end of data"
      else
        raise StandardError
      end
    end
  end

  def create_statements
    @consumption_data.each do |nmi, intervals|
      intervals.each do |interval_date, consumption_values|
        total_consumption = consumption_values.sum
        sql = "INSERT INTO meter_readings (nmi, timestamp, consumption) VALUES ('#{nmi}', '#{interval_date}', #{total_consumption});"
        @sql_statements << sql
      end
    end

    @sql_statements
  end

  def handle_nmi_data(row)
    @current_nmi = row[1]
  end

  def handle_header
    puts "this is a header"
  end

  def handle_interval(row)
    interval_date = row[1]
    consumption_values = row[2..50].map(&:to_f).sum

    @consumption_data[@current_nmi] ||= {}
    @consumption_data[@current_nmi][interval_date] ||= []
    @consumption_data[@current_nmi][interval_date] << consumption_values
  end
end

p MeterReaderMaker.new("./data.csv").call
