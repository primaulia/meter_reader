require_relative '../meter_reader.rb'

describe MeterReader do
  describe "__convert_to_kwh" do
    it "should convert MWh values to kWh" do
      instance = MeterReader.new('fixtures/sample1.csv')
      allow(instance).to receive(:current_consumption_unit).and_return('mwh')
      expect(instance.send(:convert_to_kwh, 1)).to eq(1000)
    end

    it "should convert Wh values to kWh" do
      instance = MeterReader.new('fixtures/sample1.csv')
      allow(instance).to receive(:current_consumption_unit).and_return('wh')
      expect(instance.send(:convert_to_kwh, 1)).to eq(0.001)
    end
  end

end
