require 'universa_tools/uns'

module UniversaTools
  RSpec.describe UNS do

    include TestKeys

    it "reduces" do
      UNS.reduce('hello!!!? world|-_1').should == 'he110111_vv0r1d1_1'
      UNS.reduce('hello[?]_world|-_1').should == 'he110_vv0r1d1_1'
      UNS.reduce('Ilon Ma$k').should == '110n_ma5k'
      UNS.reduce('für, maß').should == 'fvr_ma55'
      UNS.reduce('mo0n').should == 'm00n'
      UNS.reduce('français?').should == 'franca15_'
      # + UNS xlat finalizer combination test
      UNS.reduce('Ясен пень!!!!').should == '9ceh_neh61111'
      UNS.reduce('письмецо').should == 'nvc6mev0'
    end

    it "creates UNS contract" do
      # key = test_keys[0]
      # cli = Universa::Service.client
      # uns = Universa::UnsContract.new(key)
      # uns.attachToNetwork(network)
      # pp UNS.xlat1
      skip
    end

  end
end
