require 'universa_tools/key_record'

RSpec.describe UniversaTools do

  it "makes pbkdf2 KR" do
    kr = KeyRecordPbkdf2.new(rounds: 500)
    kr.encrypt('foobar', 'cryptofoobar')
    kr2 = KeyRecord.from_packed(kr.pack)
    kr2.decrypt('foobar').should == 'cryptofoobar'
    kr2.decrypt('foobar').should == 'cryptofoobar'
    kr2.decrypt('foobar').should == 'cryptofoobar'
  end

  it "serialized in arrays" do
    kr1 = KeyRecordPbkdf2.new(rounds: 500)
    kr2 = KeyRecordPbkdf2.new(rounds: 500)
    kr1.encrypt('foobar1', 'cryptofoobar')
    kr2.encrypt('foobar2', 'cryptofoobar')

    packed = KeyRecord.pack_all([kr1, kr2])

    u1, u2 = KeyRecord.unpack_all(packed)

    u1.decrypt('foobar1').should == 'cryptofoobar'
    u2.decrypt('foobar2').should == 'cryptofoobar'

    expect(-> { u1.decrypt('foobar2') }).to raise_error(Farcall::RemoteError) { |x| x.to_s.should =~ /HMAC authentication failed/ }
  end
end
