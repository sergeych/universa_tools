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

  include Singleton
  include UniversaTools

  attr :option_parser

  def initialize(&block)
    @main_password = nil
    @keyring_path = File.expand_path("~/.universa/main_keyring")
    @tasks = []
    @commands = {}
    @term_width = ANSI::Terminal.terminal_width
    init_opts &block
    init_commands()
  end

  def run
    run_options_parser @option_parser do
      name, args = ARGV[0], ARGV[1..]
      if (c = @commands[name])
        if c.dispatcher
          c.dispatcher.call(args)
        else
          self.send :"cmd_#{name}", *args
        end
      else
        error("command not found: #{name}")
      end
    end
  end

  def init_opts &initializer
    @option_parser = OptionParser.new { |opts|
      opts.banner = <<-End
#{ANSI.bold { "\nUniversa KeyRing tool #{UniversaTools::VERSION} over #{Universa::VERSION}" }}
      End
      @usage = <<-End
      
Usage:

#{sample "uniring [options] command [arguments]"}

#{sample "uniring -h"}

#{sample "uniring help"}
      End
      opts.separator ""

      opts.on("--term-with SIZE", "set terminal width to specified size when formatting output, default is taken from the terminal and is currently #@term_width.") { |size|
        @term_width = size
      }


      opts.on("--ring FILENAME", "use  specified file name as a key ring, default is #{@keyring_path}") { |path|
        @keyring_path = path
      }

      opts.on("--init", "initialize new keyring. Does not change any existing keyring") {
        task {
          File.exist?(@keyring_path) and error("key ring already exists at #@keyring_path")
        }
      }
      initializer&.call(opts)
    }
  end

  class << self
    extend Forwardable
    def_delegators :instance, *Uniring.instance_methods(false)
  end

  def cmd_list
    puts "Listing contents of #@keyring_path:"
    keyring
  end

  def keyring
    @keyring ||= KeyRing.new(@keyring_path, password: -> { keyring_password})
  end

  def keyring_password
    @keyring_password ||= begin
      "1234567890"
    end
  end

  private

  class Command

    attr :name, :description, :second_name, :dispatcher

    def initialize(name, second_name, description, dispatcher)
      @name, @second_name, @description, @dispatcher = name, second_name, description, dispatcher
    end

  end

  def cmd(name1, name2, description=nil, &block)
    if !description
      description = name2
      name2 = nil
    end
    command = Command.new(name1, name2, description, block)
    @commands[name1] = command
    @commands[name2] = command if name2
  end

  def init_commands
    cmd("help", "help on supported commands. To get extended help on some command, use 'help <command>'.") { |args|
      STDOUT.puts @option_parser.banner
      puts ""
      if args.empty?
        puts "#{ANSI.bold { "Available commands:" }}\n\n"
        cc = @commands.values.uniq
        first_column_size = cc.map { |x| x.name.size }.max + 2
        cc.each { |cmd|
          description_lines =
              first_spacer = ANSI.bold { ANSI.yellow { "%#{-first_column_size}s" % cmd.name } }
          next_spacer = ' ' * first_column_size
          cmd.description.word_wrap(@term_width - first_column_size).lines.each_with_index { |s, n|
            STDOUT << (n == 0 ? first_spacer : next_spacer)
            STDOUT.puts s
          }

        }
      else
        puts "-- not yet ready"
      end
    }

    cmd("list", "l", "show contents of the keyring")
  end

  def task(&block)
    @tasks << block
  end

  def sample(text)
    "    " + ANSI.bold { ANSI.green { text } }
  end

end

Uniring.run()