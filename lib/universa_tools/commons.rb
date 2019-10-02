require 'ansi/code'

module UniversaTools
  module Commons

    using Universa

    def human_to_i value, factor = 1000
      head, tail = value[0...-1], value[-1]
      case tail
        when 'k', 'K'
          head.to_i * 1000
        when 'M', 'm'
          head.to_i * factor * factor
        when 'G', 'g'
          head.to_i * factor * factor * factor
        else
          value.to_t
      end
    end

    def seconds_to_hms seconds
      mm, ss = seconds.divmod(60)
      hh, mm = mm.divmod(60)
      "%d:%02d:%02d" % [hh, mm, ss]
    end

    def run_options_parser(opt_parser, tasks_before_commands: false, check_empty: true, &command_parser)
      commands = opt_parser.order!
      if check_empty && @tasks.empty?
        puts opt_parser.banner
        puts "\nnothing to do. Use -h for help\n"
      else
        @tasks.each { |t| t.call } if tasks_before_commands
        command_parser&.call(commands)
        @tasks.each { |t| t.call } unless tasks_before_commands
      end
    rescue MessageException, OptionParser::ParseError => e
      STDERR.puts ANSI.red { ANSI.bold { "\nError: #{e}\n" } }
      exit(1000)
    rescue Interrupt
      exit(1010)
    rescue
      STDERR.puts ANSI.red { "\n#{$!.backtrace.reverse.join("\n")}\n" }
      STDERR.puts ANSI.red { ANSI.bold { "Error: #$! (#{$!.class.name})" } }
      exit(2000)
    end

    def todo!(text)
      raise NotImplementedError, text
    end

    def error_style(message = nil)
      message ||= yield
      ANSI.bold { ANSI.red { message } }
    end

    def success_style(message = nil)
      message ||= yield
      ANSI.bold { ANSI.green { message } }
    end

    def warning_style(message = nil)
      message ||= yield
      ANSI.bold { ANSI.yellow { message } }
    end

    alnums = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    ALNUMS = (alnums + alnums.downcase + '_' + '0123456789').chars.to_ary
    NUMBERS = "0123456789".chars.to_ary

    module CliCommands
      class Command

        attr :name, :description, :second_name, :dispatcher

        def initialize(name, second_name, description, dispatcher)
          @name, @second_name, @description, @dispatcher = name, second_name, description, dispatcher
        end

      end

      def cmd(name1, name2, description = nil, &block)
        if !description
          description = name2
          name2 = nil
        end
        command = Command.new(name1, name2, description, block)
        @commands[name1] = command
        @commands[name2] = command if name2
      end

      def cmd_list
        puts "Listing contents of #@keyring_path:"
        keyring
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
    end

    def create_temp_file_name root_path, extension
      loop do
        name = "#{root_path}/#{17.random_alnums}.#{extension}"
        return name if !File.exists?(name)
      end
    end

    # Load contratc from the path
    # @param [String] path to load contract from
    # @return [Universa::Contract]
    def load_contract(path)
      open(path, 'rb') { |f| Universa::Contract.from_packed(f.read) }
    end

    # Load private key from file
    #
    # @param [String] path to load key from
    # @param [String] password optional password
    # @return [Universa::PrivateKey]
    def load_private_key(path, password: nil)
      file_name = File.expand_path path
      if !File.exists?(file_name)
        file_name += ".private.unikey"
        raise NotFoundException.new(path) unless File.exists?(file_name)
      end
      open(file_name, 'rb') { |f| Universa::PrivateKey.from_packed(f.read, password: password) }
    end

    def error(message)
      raise UniversaTools::MessageException, message
    end
  end
end

class Integer
  def random_alnums
    to_i.times.map { UniversaTools::Commons::ALNUMS.sample }.join('')
  end

  def random_digits
    to_i.times.map { UniversaTools::Commons::NUMBERS.sample }.join('')
  end

  def random_bytes
    to_i.times.map { rand(256).chr }.join('').force_encoding('binary')
  end
end

class Numeric
  def seconds
    self
  end

  def minutes
    self*60
  end

  def hours
    self*3600
  end

  def days
    self*86400
  end
end


