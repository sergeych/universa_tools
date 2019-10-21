require 'universa_tools/keyring'

module UniversaTools

  RSpec.describe KeyRing do

    before :all do
      @tmpfolder = File.expand_path('./tmp/testrings')
      @fixtures_folder = File.expand_path('./spec/fixtures')
      FileUtils.mkdir_p(@tmpfolder)
    end

    before :each do
      FileUtils.rm_rf Dir.glob("#@tmpfolder/*")
    end

    include TestKeys

    it "creates new ring" do
      expect(-> { KeyRing.new(@tmpfolder) }).to raise_error(NotFoundException)
      kr = KeyRing.new(@tmpfolder, generate: true, password: '123123')

      kr.add_key test_keys[0], "sample tag1", foo: 'bar'
      kr.add_key test_keys[2], "sample tag2", bar: 'baz', baz: 'foo'
      kr.add_key test_keys[3], "sample tag3"

      # duplicate key error
      dupe = Universa::PrivateKey.from_packed(test_keys[2].pack)
      expect(-> { kr.add_key dupe, "sample tag4" }).to raise_error(ArgumentError)
      # duplicate tag error
      expect(-> { kr.add_key test_keys[4], "sample tag1" }).to raise_error(ArgumentError)

      kr1 = KeyRing.new(@tmpfolder, password: "123123")
      kr1["sample tag1"].should == test_keys[0]
      kr1["sample tag2"].should == test_keys[2]
      kr1["sample tag3"].should == test_keys[3]

      kr1.add_key test_keys[1], "sample tag1-1", foo: 'bar'
      kr1["sample tag1-1"].should == test_keys[1]

      kr1[test_keys[2].short_address].should == test_keys[2]
      kr1["very bad tag"].should be_nil

        # puts `ls #@tmpfolder/`
    end

    it "suports readonly" do
      kr = KeyRing.new(@tmpfolder, generate: true, password: '123123')
      kr.add_key test_keys[0], "sample tag1", foo: 'bar'

      kr1 = KeyRing.new(@tmpfolder, readonly: true, password: "123123")
      expect(-> { kr1.add_key test_keys[1], "sample tag1-1", foo: 'bar' }).to raise_error(IOError)
    end

    it "has fingerprint" do
      # prepare old keyring - copy it to not to modify in place
      puts @fixtures_folder
      FileUtils.cp_r(@fixtures_folder+"/old_keyring", @tmpfolder)
      dest = @tmpfolder + "/old_keyring"
      FileUtils.chmod(0600, Dir[dest+"/*"])
      kr = KeyRing.new(dest, password: "12341234")
      kr.fingerprint.should_not be_nil
      p kr.fingerprint
      kr2 = KeyRing.new(dest, password: "12341234")
      kr2.fingerprint.should == kr.fingerprint
    end

    it "changes password" do
      kr = KeyRing.new(@tmpfolder, generate: true, password: '123123')
      kr.add_key test_keys[0], "sample tag1", foo: 'bar'
      k1 = kr["sample tag1"]
      kr.change_password '11223344'
      expect(->{KeyRing.new(@tmpfolder, password: '123123')}).to raise_error(Farcall::RemoteError)
      kr2 = KeyRing.new(@tmpfolder, password: '11223344')
      kr2["sample tag1"].should == k1
    end

  end
end
