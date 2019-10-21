require 'ostruct'
require 'io/console'
require 'universa_tools/commons'
require 'universa_tools/errors'
require 'universa_tools/crypto_record'
require 'universa_tools/semantic_version'
require 'fileutils'

module UniversaTools

  # The key ring is useful when it is needed to keep several keys with the same password. As decryption
  # each key using a password takes lot of time, using key ring could save lot of time in server applications.
  #
  # Also, KeyRing uses individual files storage (it takes a directory to keep its contents in) even a big keyring
  # could safely and effectively be stored in the git or cloud disk. As long as the password is properly concealed
  # from sources (using some sort of secret credentials or smart deploy), it is absolutely safe to keep the keyring
  # itself in the unsafe containers (dropbox, github, google disk, etc.)
  class KeyRing

    include Commons

    attr :keys, :fingerprint

    # The record class that hold key, tag and associated information inside the ring
    KeyRecord = Struct.new(:tag, :key, :data, :file_name) do
      def save(main_key)
        open(file_name, 'wb') { |f| f << main_key.etaEncrypt(Boss.dump([0, tag, key.pack, data])) }
      end

      def self.load(main_key, file_name)
        code, tag, packed, data = open(file_name, 'rb') { |f| Boss.load(main_key.etaDecrypt(f.read)) }
        code != 0 and raise IOError, "unsupported record format #{code}"
        KeyRecord.new(tag, Universa::PrivateKey.from_packed(packed), data, file_name)
      end
    end

    def system_config
      @system_config ||= begin
        YAML.load_file File.expand_path("~/.universa/keyring_config.yml") rescue nil
      end
    end

    # Create or open key ring at the specified path.
    #
    # @param [String] path to open from/create at
    # @param [Boolean] generate true to generate if keyring does not exist
    # @param [Boolean] override to delete existing key ring if exists and create new one
    # @param [Integer] pbkdf2_rounds to generate the key
    # @param [String] salt binary string with salt for PBKDF2 key generation
    # @param [Proc] password_proc proc that takes prompt and returns password
    # @param [String] password the password to use. Only one of password or password_proc must be present
    # @param [Boolean] readonly open existing keyring in readonly mode to prevent any modification
    def initialize(path, generate: false, override: false, pbkdf2_rounds: 500000, salt: path[0..].force_encoding('binary'),
                   password_proc: -> (prompt) { console_password_input(prompt) }, password: nil, readonly: false)
      @generate, @override, @pbkdf2_rounds, @salt = generate, override, pbkdf2_rounds, salt
      @password_proc, @password = password_proc, password
      @readonly = readonly

      @readonly && (@generate || @override) and raise ArgumentError, "readonly is incompatible with override or generate"
      @key_tags = {}
      @key_addresses = {}
      @keys = []

      @root_path = File.expand_path(path)
      exists = File.exist?(config_file_name)
      case
        when @generate && exists
          if @override
            FileUtils.rm_rf Dir.glob("#@root_path/*")
            generate_new()
          else
            error "Can't generate: keyring already exists"
          end
        when @generate && !exists
          generate_new()
        when exists
          open_keyring()
        else
          raise NotFoundException.new(path)
      end
    end

    # Add key to the ring. Will not change the ring of the key already exists
    def add_key(key, tag = nil, **key_data)
      will_write!
      raise ArgumentError, "the key tagged #{tag} already exists" if tag && @key_tags[tag]
      if @key_addresses[key.short_address] || @key_addresses[key.long_address]
        raise ArgumentError, "key is already in the ring"
      end
      kr = KeyRecord.new(tag, key, key_data, create_temp_file_name(@root_path, 'data'))
      kr.save(@main_key)
      @keys << kr
      @key_tags[tag] = kr
      @key_addresses[key.short_address] = kr
      @key_addresses[key.long_address] = kr
    end

    # Get oll matching {KeyRecord} instances where the tag starts with the prefix (case-insensitive), or string
    # representation of short or long address starts woth the prefix (case-sensitive)
    #
    # @param [String] prefix to look for in tags and addresses
    # @return [Array(KeyRecord)] all matching records, could be empty.
    def matching_records(prefix)
      pd = prefix.downcase
      @keys.select { |r|
        r.tag&.downcase&.start_with?(pd) ||
            r.key.long_address.to_s.start_with?(prefix) ||
            r.key.short_address.to_s.start_with?(prefix)
      }
    end

    # Find a key by tag or address.
    # @param [String | KeyAddress] tag_or_address to look for. String could be a tag or string representation of
    #            KeyAddress
    # @return [PrivateKey] or nil
    def [](tag_or_address)
      find(tag_or_address)&.key
    end

    # Get the associated data
    # @param [String | KeyAddress] tag_or_address to look for
    # @return [Hash] that could be empty or nil if the key is not found
    def info(tag_or_address)
      find(tag_or_address)&.data
    end

    # Retreive the tag by the key or its address
    # @param [KeyAddress] address
    # @param [PrivateKey] key
    # @return [String] tag of the key or nil if there is no tag or key not found
    def tag_by(address: nil, key: nil)
      case
        when key
          @keys.find[key]&.tag
        when address
          @key_addresses[address]&.tag
        else
          raise ArgumentError, "no criterion specified"
      end
    end

    # KeyRing version
    # @return [SemanticVersion]
    def version
      @version ||= SemanticVersion.new(@header['version'])
    end

    # delete the key off the ring
    # @raise [NotFoundException] if such a key is not in the ring
    def delete_key key
      record = @keys.find { |r| r.key == key }
      record or raise NotFoundException
      record.tag && @key_tags.delete(record.tag)
      @key_addresses.delete(record.key.long_address)
      @key_addresses.delete(record.key.short_address)
      @keys.delete record
      FileUtils.rm_f record.file_name
    end

    def change_password new_password
      will_write!
      @main_record = Pbkdf2CryptoRecord.new(hint: 'main password', salt: 42.random_alnums)
      @main_record.encrypt(new_password, @main_key.pack)
      write_config()
    end

    private

    def find(tag_or_address)
      k = @key_tags[tag_or_address] and return k
      address = tag_or_address.is_a?(Universa::KeyAddress) ? tag_or_address : Universa::KeyAddress.new(tag_or_address)
      @keys.select { |kr| address.isMatchingKey(kr.key.public_key) }.first
    rescue Farcall::RemoteError
      raise $! if $!.message !~ /IllegalArgumentException/
      # it is just a missing tag
      nil
    end

    def console_password_input(prompt)
      loop do
        puts prompt
        psw = STDIN.noecho { |io| io.gets.chomp }
        puts "reenter password"
        psw1 = STDIN.noecho { |io| io.gets.chomp }
        psw1 == psw and return psw
        puts "password do no match, please try again"
      end
    end

    def request_password(text)
      @password || @password_proc.call(text)
    end

    def get_key
      todo!
    end

    def config_file_name
      @config_file_name ||= @root_path + "/uniring.unirecord"
    end

    def write_config
      will_write!
      delete_file(backup_file_name)
      FileUtils.mv(config_file_name, backup_file_name) if File.exists?(config_file_name)
      open(config_file_name, 'wb') { |x|
        out = Boss::Formatter.new(x)
        out << @header << CryptoRecord.pack_all([@main_record])
      }
      delete_file(backup_file_name)
    end

    def backup_file_name
      @backup_file_name ||= config_file_name + '~'
    end

    # delete file if exists
    def delete_file(backup_file_name)
      will_write!
      FileUtils.rm(backup_file_name) if File.exists?(backup_file_name)
    end

    def open_keyring
      read_config()
      Dir.glob("#{@root_path}/*.data") { |path|
        kr = KeyRecord.load(@main_key, path)
        @keys << kr
        @key_addresses[kr.key.short_address] = kr
        @key_addresses[kr.key.long_address] = kr
        @key_tags[kr.tag] = kr if kr.tag
      }
    end

    # dead existing ring configuration, needs to unlock after it.
    def read_config
      try_read(config_file_name)
      @main_record or raise IOError("main key not found")
      unpacked = nil
      if (pwd=system_config&.dig("keyrings", @fingerprint, "password")) != nil
        unpacked = @main_record.try_decrypt(pwd)
      end
      unpacked ||= @main_record.decrypt(request_password("password to open repository"))
      @main_key = Universa::SymmetricKey.new(unpacked)
    rescue IOError
      # potentially recoverable
      puts error_style("failed to open keyring: #$!")
      try_read(backup_file_name)
      puts "Backup keyring loaded"
    end

    # Try to read config from main or backup file
    # @raise if it is not possible
    def try_read(name)
      open(config_file_name, 'rb') { |input|
        parser = Boss::Parser.new(input)
        @header = parser.get
        @crypto_records = CryptoRecord.unpack_all(parser.get)
        @main_record = @crypto_records.find { |r| r.is_a?(Pbkdf2CryptoRecord) }
      }
      @fingerprint = @header['fingerprint']&.freeze or begin
        @header['fingerprint'] = @fingerprint = 31.random_alnums.freeze
        write_config()
      end
    end

    # creates new record if no exist. Does not wipe existing ring.
    # @raise [Exception] on failure.
    def generate_new
      will_write!
      FileUtils.mkdir_p(@root_path)
      FileUtils.chmod(0700, @root_path)

      @main_key = Universa::SymmetricKey.new()
      @main_record = Pbkdf2CryptoRecord.new(hint: 'main password', salt: 42.random_alnums)
      @main_record.encrypt request_password("main password for the new keyring"), @main_key.pack
      @fingerprint = 31.random_alnums.freeze
      @header = {tag: 'uniring', version: '0.1.0', fingerprint: @fingerprint}
      write_config()
    end

    def will_write!
      @readonly and raise IOError, "keying is readonly"
    end

  end
end