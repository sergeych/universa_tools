require 'universa_tools/crypto_record'

RSpec.describe UniversaTools do

  it "makes pbkdf2 KR" do
    kr = Pbkdf2CryptoRecord.new(rounds: 500)
    kr.encrypt('foobar', 'cryptofoobar')
    kr2 = CryptoRecord.from_packed(kr.pack)
    kr2.decrypt('foobar').should == 'cryptofoobar'
    kr2.decrypt('foobar').should == 'cryptofoobar'
    kr2.decrypt('foobar').should == 'cryptofoobar'
  end

  it "serialized in arrays" do
    kr1 = Pbkdf2CryptoRecord.new(rounds: 500)
    kr2 = Pbkdf2CryptoRecord.new(rounds: 500)
    kr1.encrypt('foobar1', 'cryptofoobar')
    kr2.encrypt('foobar2', 'cryptofoobar')

    packed = CryptoRecord.pack_all([kr1, kr2])

    u1, u2 = CryptoRecord.unpack_all(packed)

    u1.decrypt('foobar1').should == 'cryptofoobar'
    u2.decrypt('foobar2').should == 'cryptofoobar'

    expect(-> { u1.decrypt('foobar2') }).to raise_error(Farcall::RemoteError) { |x| x.to_s.should =~ /HMAC authentication failed/ }
  end

  it "can be re-saved without re/ecnrypting" do
    kr1 = Pbkdf2CryptoRecord.new(rounds: 500)
    kr2 = Pbkdf2CryptoRecord.new(rounds: 500)
    kr1.encrypt('foobar1', 'cryptofoobar')
    kr2.encrypt('foobar2', 'cryptofoobar')

    packed = CryptoRecord.pack_all([kr1, kr2])
    array = CryptoRecord.unpack_all(packed)
    packed = CryptoRecord.pack_all(array)
    u1, u2 = CryptoRecord.unpack_all(packed)
    u1.decrypt('foobar1').should == 'cryptofoobar'
    u2.decrypt('foobar2').should == 'cryptofoobar'
  end
end
