require 'universa'
require 'universa_tools/u_wallet'
require 'universa_tools/commons'

module UniversaTools

  describe "u_wallet" do

    include Commons

    it "constructs" do
      uw = UWallet.new("~/.universa/U/Uwork.unicon",
                       key: load_private_key("~/.universa/keys/sergeych_work"))
      p uw.balance
      # name = File.expand_path("~/.universa/U/Uwork.unicon")
      # u = Universa::Contract.from_packed(open(name, 'rb'){|x| x.read})
      # puts u.definition.to_h
      # puts u.issuer.getSimpleAddress
      # puts u.state.to_h
    end

  end
end