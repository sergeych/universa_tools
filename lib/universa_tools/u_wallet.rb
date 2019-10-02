require 'ostruct'
require 'io/console'
require 'universa_tools/commons'
require 'universa_tools/errors'
require 'universa_tools/crypto_record'
require 'universa_tools/semantic_version'
require 'fileutils'

=begin

u_wallet file structure

path.unicon   # always
path.unicon~  # sometimes, previous version

=end

module UniversaTools

  class Universa::Parcel
    static_method :of
    static_method :unpack
  end

  # Under construction. FS-based U wallet. This version misses support for multiple-resulting paying parcel
  # operation, so it will be completely reqwritten. Please do not use.
  class UWallet
    include Universa

    # U left
    attr :balance

    # TestU left
    attr :test_balance

    # @param [String] path to the U ucontract
    # @param [PrivateKey] key for the UContract
    # @param [KeyRing] keyring to look for a key in
    # @param [Universa::Client] client to connect to the Universa
    def initialize(path, key: nil, keyring: nil, client: nil)
      key || keyring or raise ArgumentError, "key or keyring must be presented"
      key && keyring and raise ArgumentError, "only one of key or keyring must be presented"
      @client = client || Universa::Client.new
      restore_state path
      check_key(key, keyring)
      @mutex = Mutex.new
    end

    def busy?
      @mutex.locked?
    end

    def register contract
      @mutex.synchronize {
        contract.check or raise ArgumentError, "contract is not OK"
        units = contract.getProcessedCostU()
        puts "cost #{units}"
        parcel = Universa::Parcel.of(contract, @u, [@key])
        p parcel
        raise InsufficientFundsException if units > balance
        # @client.2
      }
    end

    private

    def restore_state(path)
      @current_name = File.expand_path path
      # current path may not exist if the, say commit or rollback operation were interrupted
      if File.exists?(@current_name)
        @u = load_u(@current_name)
        if @client.get_state(@u).approved?
          delete_backup()
          set_balance()
          return
        end
      end
      # main state is bad or missing - checking prev state
      @u = load_u(backup_name)
      if (@client.get_state(@u)).approved?
        rollback()
      else
        error("No valid U contracts found")
      end
    end

    # Load and check U contract, check that it is a valid U contract, does not checks it state!
    # @param [String] path to load contract from
    # @return [Contract]
    def load_u(path)
      u = open(path, 'rb') { |f| Contract.from_packed(f.read) }
      d = u.definition
      # {"issuerName"=>"Universa Reserve System", "name"=>"transaction units pack"}
      # J3uaVvHE7JqhvVb1c26RyDhfJw9eP2KR1KRhm2VdmYx7NwHpzdHTyEPjcmKpgkJAtzWLSPUw
      p u.issuer.getSimpleAddress.to_s
      if d['issuerName'] != 'Universa Reserve System' || d['name'] != 'transaction units pack' ||
          u.issuer.getSimpleAddress.to_s != 'J3uaVvHE7JqhvVb1c26RyDhfJw9eP2KR1KRhm2VdmYx7NwHpzdHTyEPjcmKpgkJAtzWLSPUw'
        error("not a U contract")
      end
      u
    end

    def delete_backup
      File.exists?(backup_name) and FileUtils.rm(backup_name)
    end

    def backup_name
      @back_name ||= @current_name + "~"
    end

    def set_balance
      @balance = @u.state.transaction_units
      @test_balance = @u.state.test_transaction_units
    end

    # last become main
    # main dissapears
    def rollback
      File.exists?(@current_name) and FileUtils.rm(@current_name)
      # if it is interrupted, it will correctly restore on next run
      FileUtils.move backup_name, @current_name
      @u = load_u(@current_name)
      set_balance
    end

    def check_key(key, keyring)
      address = @u.owner.getSimpleAddress
      @key = if key
               address.isMatchingKey(key.public_key) or raise ArgumentError, "key is wrong"
               key
             else
               keyring[address] or raise ArgumentError, "keyring does not contain required key"
             end
    end

  end
end