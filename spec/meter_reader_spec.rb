require_relative '../meter_reader.rb'

describe MeterReader do
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
