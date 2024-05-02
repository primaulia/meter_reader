require 'csv'
require 'pry-byebug'

class MeterReaderMaker
  def initialize(filepath)
    @filepath = filepath
    @sql_queries = []

    parse_csv
  end

  private

  def parse_csv
    CSV.foreach(@filepath) do |row|
      record_indicator = row.first.to_i

      case record_indicator
      when 100 then handle_header
      when 200 then puts "nmi"
      when 300 then puts "interval data"
      when 400 then puts "interval event"
      when 500 then puts "b2b"
      when 900 then puts "end of data"
      else
        raise StandardError
      end
    end
  end

  def handle_header
    puts "this is a header"
  end
end

MeterReaderMaker.new("./data.csv")
