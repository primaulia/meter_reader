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
end
