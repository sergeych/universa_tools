require 'universa_tools/keyring'
require 'universa_tools/uniring'

class ExitException < Exception
  attr :exit_code

  def initialize(code)
    @exit_code = code
  end
end

alias :old_exit :exit

$exit_hooked = false

def exit(code = 0)
  if $exit_hooked
    raise ExitException.new(code)
  else
    old_exit(code)
  end
end

module UniversaTools

  RSpec.describe "uniring utility" do

    include TestKeys

    before :all do
      @keyring_path = File.expand_path('./tmp/testrings')
      FileUtils.mkdir_p(@keyring_path)
      $exit_hooked = true
      @pwd = "sic_transit_and_shit_happens"
    end

    after :all do
      $exit_hooked = false
    end

    before :each do
      FileUtils.rm_rf Dir.glob("#@keyring_path/*")
    end

    include TestKeys

    it "shows help" do
      start "-h"
    end

    it "creates empty ring" do
      start "-p #{@pwd} --init #@keyring_path"
      # start "-p #{@pwd} -l #@keyring_path"
      # KeyRing.new(@keyring_path, password: @pwd).keys.size.should == 0
    end

    it "add keys" do
      keypass = '1;23klj4'
      f1 = make_key_file(0, keypass)
      f2 = make_key_file(1, keypass)
      p f1
      p f2
      start "-p #{@pwd} --init #@keyring_path"
      start "-p #{@pwd} --add #{f1}:#{keypass} --add tag2,#{f2}:#{keypass} -l #@keyring_path"
    end

    def make_key_file(n, password = "keypass123")
      FileUtils.mkdir_p "./tmp/teskteys"
      file_name = "./tmp/teskteys/test_#{n}.private.unikey"
      unless File.exists?(file_name)
        open(file_name, 'wb') { |f| f << test_keys[n].pack_with_password(password, 100) }
      end
      file_name
    end

    def start cmdline
      begin
        ARGV.replace cmdline.split(/\s+/)
        Uniring.new.run()
      rescue ExitException => e
        e.exit_code
      end
    end

  end
end
