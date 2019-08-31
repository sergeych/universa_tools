require 'ostruct'
require 'io/console'
require 'universa_tools/commons'
require 'universa_tools/crypto_record'

module UniversaTools

  class KeyRing

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

    # Create or open key ring at the specified path
    # @param [String] path to open from/create at
    # @param [Object] generate true to generate if keyring does not exist
    # @param [Object] override to delete existing key ring if exists and create new one
    # @param [Object] pbkdf2_rounds to generate the key
    # @param [Object] salt for PBKDF2 key generation
    # @param [Object] password_proc proc that takes prompt and returns password
    # @param [Object] password the password to use. Only one of password or password_proc must be present
    # @param [Object] readonly open existing keyring in readonly mode to prevent any modification
    def initialize(path, generate: false, override: false, pbkdf2_rounds: 500000, salt: path.force_encoding('binary'),
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

    def add_key(key, tag = nil, **key_data)
      will_write!
      # todo: merge data if exist
      kr = KeyRecord.new(tag, key, key_data, create_temp_file_name('data'))
      raise ArgumentError, "the key tagged #{tag} already exists" if tag && @key_tags[tag]
      if key.respond_to?(:short_address) &&
          (@key_addresses[key.short_address.to_s] || @key_addresses[key.long_address.to_s])
        raise ArgumentError, "key is already in the ring"
      end
      kr.save(@main_key)
      @keys << kr
      @key_tags[tag] = kr
      @key_addresses[key.short_address.to_s] = kr
      @key_addresses[key.long_address.to_s] = kr
    end

    def [](tag_or_address)
      find(tag_or_address)&.key
    end

    def info(tag_or_address)
      find(tag_or_address)&.data
    end

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

    private

    def find(tag_or_address)
      @key_tags[tag_or_address] || @key_addresses[tag_or_address]
    end

    def create_temp_file_name extension
      loop do
        name = "#{@root_path}/#{17.random_alnums}.#{extension}"
        return name if !File.exists?(name)
      end
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
      # todo: safe overwrite
      delete_file(backup_file_name)
      FileUtils.mv(config_file_name, backup_file_name) if File.exists?(config_file_name)
      open(config_file_name, 'wb') { |x|
        out = Boss::Formatter.new(x)
        out << {tag: 'uniring', version: '0,1,0'} << CryptoRecord.pack_all([@main_record])
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
        @key_addresses[kr.key.short_address.to_s] = kr
        @key_addresses[kr.key.long_address.to_s] = kr
        @key_tags[kr.tag] = kr if kr.tag
      }

    end

    # dead existing ring configuration, needs to unlock after it.
    def read_config
      try_read(config_file_name)
      @main_record or raise IOError("main key not found")
      @main_key = Universa::SymmetricKey.new(@main_record.decrypt(request_password("password to open repository")))
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
    end

    # creates new record if no exist. Does not wipe existing ring.
    # @raise [RuntimeError] on failure.
    def generate_new
      will_write!
      FileUtils.mkdir_p(@root_path)
      FileUtils.chmod(0700, @root_path)

      @main_key = Universa::SymmetricKey.new()
      @main_record = Pbkdf2CryptoRecord.new(hint: 'main password')
      @main_record.encrypt request_password("main password for the new keyring"), @main_key.pack

      write_config()
    end

    def will_write!
      @readonly and raise IOError, "keying is readonly"
    end

  end
end