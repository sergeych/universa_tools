require 'optparse'
require 'ostruct'
require 'ansi/code'
require 'ansi/terminal'
require 'universa'
require 'universa_tools'
require 'universa_tools/keyring'
require 'facets/string/word_wrap'

include Universa

# Show help it nothing to do
# ARGV << "-h" if ARGV == []

class Uniring

  include UniversaTools::Commons
  include UniversaTools

  attr :option_parser

  def initialize(&block)
    @main_password = nil
    @keyring_path = File.expand_path("~/.universa/main_keyring")
    @tasks = []
    @commands = {}
    @term_width = ANSI::Terminal.terminal_width
    init_opts &block
  end

  def run
    run_options_parser @option_parser, tasks_before_commands: false do
      case ARGV.length
        when 0
          # OK, run as usual
        when 1
          @keyring_path = ARGV[0]
        else
          error("illegal arguments")
      end
    end
  end

  def init_opts &initializer
    @option_parser = OptionParser.new { |opts|
      opts.banner = <<-End
#{ANSI.bold { "\nUniversa KeyRing tool #{UniversaTools::VERSION}, Universa core #{Universa::VERSION}" }}
      End
      @usage = <<-End
      
Usage:

#{sample "uniring [options] command [arguments]"}

#{sample "uniring -h"}

#{sample "uniring help"}
      End
      opts.separator ""

      # opts.on("--term-with SIZE", "override terminal width to specified size when formatting output, default is taken from the terminal and is currently #@term_width.") { |size|
      #   @term_width = size
      # }

      opts.on("--all", "allow delete/update more than one key at a time") {
        @allow_all = true
      }

      opts.on("-p PASSWORD", "--password PASSWORD", "specify keyring password in the command line") { |x|
        @password = x
      }

      opts.on("-a [TAG,]KEY_FILE", "--add [TAG,]KEYFILE", Array, "add key from a file, with optional tag",
              "tag could be used to select keys in extract/sign/delete operations") { |tag, file_name|
        task {
          if !file_name
            tag, file_name = file_name, tag
          end
          file_name, password = file_name.split(':', 2)
          begin
            keyring.add_key load_key(file_name, password), tag
            puts success_style("\nKey added\n")
          rescue ArgumentError
            error "key already in ring"
          end
        }
      }

      opts.on("-d prefix", "--delete prefix", "delete key by beginning of its key address or a tag",
              "this method prompts confirmation works only if exactly one",
              "matching key exists") { |part| task {
        keys = keyring.matching_records(part)
        case keys.size
          when 0
            error "no matching keys found"
          when 1
            delete_keys(keys)
          else
            if @allow_all
              delete_keys(keys)
            else
              puts error_style("\nMore than one key matches the criteria:")
              keys.each { |kr| show_record kr }
              error "Only one key could be deleted unless --all is specified"
            end
        end
      } }

      opts.on("-l", "--list", "show keys in a ring") {
        task {
          keyring # this may ask for password so do it first
          puts "--" * 40
          puts ANSI.yellow { "KeyRing v.#{keyring.version.to_s}: " } + ANSI.bold { @keyring_path }
          puts ANSI.yellow { "fingerprint:     " } + ANSI.bold{ ANSI.green { keyring.fingerprint } }
          puts "--" * 40
          keyring.keys.sort_by { |x| x&.tag || '' }.each(&method(:show_record))
          if (keyring.keys.size > 0)
            puts "--" * 40
            puts "#{keyring.keys.size} key(s)\n"
          else
            puts "\nno keys\n"
          end
        }
      }

      opts.on("-x", "--change-password [NEW_PASSWORD]",
              "change password. if the password it not specified, it ",
              "will be requested. Don't forget to use -- to separate",
              "this option from the repository name when needed") { |np|
        task {
          kr = keyring
          new_password = np || request_password2("enter new password")
          kr.change_password new_password
          puts "password has been changed"
        }
      }

      opts.on("--init", "-i", "initialize new keyring. Does not change any existing keyring") {
        task {
          @keyring = KeyRing.new(@keyring_path, password: @password, password_proc: ->(x) { self.request_password2 x },
                                 generate: true, override: @force_init)
          puts success_style("keyring has been created")
        }
      }

      opts.on("--force", "with --init, deletes existing reing if exists") {
        @force_init = true
      }

      initializer&.call(opts)

    }
  end

  def keyring
    @keyring ||=
        begin
          print ANSI.faint { "trying to open keyring #{@keyring_path}" }
          KeyRing.new(@keyring_path, password: @password, password_proc: -> (x) { self.request_password(x) } )
        rescue Farcall::RemoteError => e
          if e.message =~ /HMAC authentication failed/
            error("wrong keyring password or broken ring")
          else
            raise e
          end
        ensure
          print "\r" + ' ' * 20 + "\r"
        end
  end

  def keyring_password
    @keyring_password
  end

  def request_password2(prompt)
    loop do
      psw1 = request_password prompt
      psw2 = request_password "please re-enter the password"
      return psw1 if psw1 == psw2
      puts error_style("passwords do not much. try again")
    end
  ensure
    clearstring
  end

  def request_password(prompt)
    clearstring
    print prompt + ' '
    STDIN.noecho { |x| x.gets.chomp }
  ensure
    clearstring
  end

  private

  def delete_keys(keys)
    keys.each { |kr|
      show_record kr
      print warning_style { "Are you sure to delete this key? [Ny] " }
      if %w[y Y].include?(STDIN.readline.chomp)
        print "deleting..."
        keyring.delete_key kr.key
        clearstring
        puts warning_style("\nkey has been deleted\n")
      else
        puts "skipped"
      end
    }
  end

  def show_record(kr)
    puts ANSI.bold { ANSI.green { kr.tag } } || ANSI.faint { "(no tag)" }
    puts "\t#{ANSI.bold { kr.key.short_address.to_s }}"
    puts "\t#{ANSI.bold { kr.key.long_address.to_s }}"
    if !kr.data.empty?
      puts "\t#{kr.data.inspect}"
    end
    puts
  end

  def load_key(file_name, password = nil)
    packed = open(file_name, 'rb') { |f| f.read } rescue open(file_name + ".private.unikey", 'rb') { |f| f.read }
    # NO password?
    key = Universa::PrivateKey.from_packed(packed) rescue nil
    key and return key
    print ANSI.faint("decrypting the key...")
    if password
      key = Universa::PrivateKey.from_packed(packed, password: password) rescue nil
      clearstring()
      key and return key
      puts error_style("wrong password or corrupted key file")
    end
    while !key do
      password = request_password("\rPlease enter password for #{file_name}:")
      print ANSI.faint("\rdecrypting the key...")
      key = Universa::PrivateKey.from_packed(packed, password: password) rescue nil
      clearstring()
      key or puts error_style("wrong password or corrupted key file")
    end
    key
  end

  def clearstring()
    print "\r" + ' ' * 120 + "\r"
  end

  def task(&block)
    @tasks << block
  end

  def sample(text)
    "    " + ANSI.bold { ANSI.green { text } }
  end

end

