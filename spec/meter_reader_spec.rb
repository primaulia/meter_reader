require_relative '../meter_reader.rb'

describe MeterReader do
  def extract_timestamps_from_statement(statement)
    timestamp_pattern = /(\d{4}-\d{2}-\d{2})/
    Date.parse(statement.match(timestamp_pattern)[1])
  end

  context "sample 1 (1 NMI, multiple 300 records, 30 mins interval, 1 kWh meter reading, 2004-02-01)" do
    describe "#call" do
      let(:instance) { described_class.new('fixtures/sample1.csv') }

      it "should return 48 insert statements" do
        expect(instance.call.size).to eq(48)
      end

      it "should return meter readings within the same day" do
        statements = instance.call
        first_timestamp = extract_timestamps_from_statement(statements.first)
        last_timestamp = extract_timestamps_from_statement(statements.last)
        expect(first_timestamp.to_s).to eq('2004-02-01')
        expect((last_timestamp - first_timestamp).to_i).to eq(1)
      end
    end
  end

  context "sample 2 (1 NMI, multiple 300 records, 30 mins interval, 1 kWh meter reading, 2003-08-01)" do
    describe "#call" do
      let(:instance) { described_class.new('fixtures/sample2.csv') }

      it "should return 48 insert statements" do
        expect(instance.call.size).to eq(48)
      end

      it "should return meter readings within the same day" do
        statements = instance.call
        first_timestamp = extract_timestamps_from_statement(statements.first)
        last_timestamp = extract_timestamps_from_statement(statements.last)
        expect(first_timestamp.to_s).to eq('2003-08-01')
        expect((last_timestamp - first_timestamp).to_i).to eq(1)
      end
    end
  end

  context "sample 3 (1 NMI, multiple 300 records, 30 mins interval, 1 kWh meter reading, 2003-12-19 to 2003-12-25)" do
    describe "#call" do
      let(:instance) { described_class.new('fixtures/sample3.csv') }

      it "should return 7 days worth of insert statements" do
        expect(instance.call.size).to eq(336)
      end

      it "should return meter readings across 7 days" do
        statements = instance.call
        first_timestamp = extract_timestamps_from_statement(statements.first)
        last_timestamp = extract_timestamps_from_statement(statements.last)
        expect(first_timestamp.to_s).to eq('2003-12-19')
        expect(last_timestamp.to_s).to eq('2003-12-26')
        expect((last_timestamp - first_timestamp).to_i).to eq(7)
      end
    end
  end

  context "sample 4 (2 NMIs, but only 1 NMI that has active consumption data, multiple 300 records, 15 mins interval, 2 Wh meter readings, 20031204 to 20031205)" do
    describe "#call" do
      let(:instance) { described_class.new('fixtures/sample4.csv') }

      it "should return 2 days worth insert statements" do
        expect(instance.call.size).to eq(192)
      end

      it "should return meter readings across 2 days" do
        statements = instance.call
        first_timestamp = extract_timestamps_from_statement(statements.first)
        last_timestamp = extract_timestamps_from_statement(statements.last)
        expect(first_timestamp.to_s).to eq('2003-12-04')
        expect(last_timestamp.to_s).to eq('2003-12-06')
        expect((last_timestamp - first_timestamp).to_i).to eq(2)
      end
    end
  end

  context "sample 6 (1 NMIs, multiple meter with multiple 300 records, 30 mins interval, 2 Wh meter readings, 20040809 to 20040812)" do
    describe "#call" do
      let(:instance) { described_class.new('fixtures/sample6.csv') }

      it "should return 3 days worth of insert statements" do
        expect(instance.call.size).to eq(144)
      end

      it "should return meter readings across 3 days" do
        statements = instance.call
        first_timestamp = extract_timestamps_from_statement(statements.first)
        last_timestamp = extract_timestamps_from_statement(statements.last)
        expect(first_timestamp.to_s).to eq('2004-08-09')
        expect(last_timestamp.to_s).to eq('2004-08-12')
        expect((last_timestamp - first_timestamp).to_i).to eq(3)
      end
    end
  end

  context "sample 9 (1 NMIs, multiple 300 records, 5 mins interval, 1 kWh meter readings, 20220201)" do
    describe "#call" do
      let(:instance) { described_class.new('fixtures/sample9.csv') }

      it "should a day worth of insert statements" do
        expect(instance.call.size).to eq(288)
      end

      it "should return meter readings within a day" do
        statements = instance.call
        first_timestamp = extract_timestamps_from_statement(statements.first)
        last_timestamp = extract_timestamps_from_statement(statements.last)
        expect(first_timestamp.to_s).to eq('2022-02-01')
        expect(last_timestamp.to_s).to eq('2022-02-02')
        expect((last_timestamp - first_timestamp).to_i).to eq(1)
      end
    end
  end

  describe "__convert_to_kwh" do
    let(:instance) { described_class.new('fixtures/sample1.csv') }

    it "should convert MWh values to kWh" do
      allow(instance).to receive(:current_consumption_unit).and_return('mwh')
      expect(instance.send(:convert_to_kwh, 1)).to eq(1000)
    end

    it "should convert Wh values to kWh" do
      allow(instance).to receive(:current_consumption_unit).and_return('wh')
      expect(instance.send(:convert_to_kwh, 1)).to eq(0.001)
    end

    it "should raise ArgumentError if the value is not an integer" do
      expect{ instance.send(:convert_to_kwh, "test") }.to raise_error(ArgumentError)
    end

    it "should raise a StandardError if the current_consumption_unit does not exist yet" do
      allow(instance).to receive(:current_consumption_unit).and_return('dwh')
      expect{ instance.send(:convert_to_kwh, 1) }.to raise_error(StandardError)
    end
  end

  describe "__prepare_timestamp" do
    let(:instance) { described_class.new('fixtures/sample1.csv') }

    it "should prepare the correct timestamp given the date" do
      allow(instance).to receive(:current_interval_length).and_return(30)
      expect(instance.send(:prepare_timestamp, '20040201')).to eq(Time.new(2004, 2, 1, 0, 30, 0))
    end

    it "should raise error if it's an invalid date" do
      expect { instance.send(:prepare_timestamp, 'xxx') }.to raise_error(Date::Error)
    end
  end

  describe "__process_nmi_record" do
    let(:instance) { described_class.new('fixtures/sample1.csv') }

    it "should derive the current meter state according the given line" do
      valid_line = "200,VABD000163,E1Q1,1,E1,N1,METSER123,kWh,30,"
      result = instance.send(:process_nmi_record, valid_line)

      expect(result.keys).to match_array(%i[nmi unit interval_length nmi_suffix])
      expect(result).to eq({
        nmi: 'VABD000163',
        unit: 'kwh',
        interval_length: 30,
        nmi_suffix: 'e1'
      })
    end

    it "should raise ArgumentError if the 200 record given is invalid" do
      invalid_line = "lorem ipsum"
      expect { instance.send(:process_nmi_record, invalid_line) }.to raise_error(ArgumentError)
    end
  end

  describe "__process_interval_records" do
    let(:instance) { described_class.new('fixtures/sample1.csv') }

    it "should raise ArgumentError if the 300 record given is invalid" do
      invalid_line = "lorem ipsum"
      expect { instance.send(:process_interval_record, invalid_line) }.to raise_error(ArgumentError)
    end

    it "should provided the essential interval record if the data is valid" do
      valid_line = "300,20040201,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,1.1112,A,,,20040202120025,20040202142516"

      allow(instance).to receive(:current_interval_length).and_return(30)
      result = instance.send(:process_interval_record, valid_line)
      expect(result.keys).to match_array(%i[consumption_values time])
      expect(result[:consumption_values].length).to eq(48)
      expect(result[:time].class).to eq(Time)
      expect(result[:time]).to eq(instance.send(:prepare_timestamp, '20040201'))
    end
  end
end
