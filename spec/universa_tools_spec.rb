require 'universa_tools/uns'

module UniversaTools
  RSpec.describe UniversaTools do
    include TestKeys

    it "has a version number" do
      expect(UniversaTools::VERSION).not_to be nil
    end

    it "can create UNS contract" do
      key = test_keys[0]
      # cli = Universa::Service.client
      # uns = Universa::UnsContract.new(key)
      # uns.attachToNetwork(network)
      # pp UNS.xlat1
      UNS.reduce('hello!!!? world|-_1').should == 'he110_vv0r1d_1'
      UNS.reduce('hello[?]_world|-_1').should == 'he110_vv0r1d_1'
      UNS.reduce('für, maß').should == 'fvr_ma55'
      UNS.reduce('mo0n').should == 'm00n'
      UNS.reduce('Ясен пень!!!!').should == 'яceh_пehb_'
    end

  end
end
