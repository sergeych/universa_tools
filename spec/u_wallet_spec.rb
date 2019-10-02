require 'universa'
require 'universa_tools/u_wallet'
require 'universa_tools/commons'
require 'universa_tools/uns'

module UniversaTools

  describe "u_wallet" do

    include Commons
    include TestKeys

    before :all do
      @client = Universa::Client.new
    end

    it "constructs" do
      uw = UWallet.new("~/.universa/U/Uwork.unicon",
                       key: load_private_key("~/.universa/keys/sergeych_work"))
      p uw.balance
      uw.balance.should > 0

      key = test_keys[0]
      c = Universa::Contract.new(key)
      c.expires_at = Time.now + 5.days
      c.state.hello = "world"
      c.seal
      uw.register c
      # name = File.expand_path("~/.universa/U/Uwork.unicon")
      # u = Universa::Contract.from_packed(open(name, 'rb'){|x| x.read})
      # puts u.definition.to_h
      # puts u.issuer.getSimpleAddress
      # puts u.state.to_h
    end

    it "pays uns" do
      skip "needs reqrite"
      # issuer = test_keys[0]
      # nskey = test_keys[1]
      # uns = Universa::UnsContract.new(issuer)
      # uns.attachToNetwork(@client.random_connection.umi_client)
      # name = "name1"
      # reducedName = UNS::reduce(name)
      # uns.addName(name,reducedName,"description")
      # uns.addData({"foo" =>"bar"})
      #
      # uns.addSignerKey(issuer)
      # uns.addSignerKey(nskey)
      #
      # uns.seal()
      #
      # p uns.getPayingAmount(Time.now + 1.days)
      # p uns.getPayingAmount(Time.now + 2.days)
      # p uns.getPayingAmount(Time.now + 100.days)
      # p uns.getPayingAmount(Time.now + 10.days)
      # p uns.getPayingAmount(Time.now + 100.days)
      # p uns.getPayingAmount(Time.now + 365.days)
    end

  end
end