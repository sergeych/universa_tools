require 'ansi/code'

module UniversaTools

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

  def run_options_parser(opt_parser, &command_parser)
    commands = opt_parser.order!
    if @tasks.empty? && commands.empty?
      puts opt_parser.banner
      puts "\nnothing to do. Use -h for help\n"
    else
      @tasks.each { |t| t.call }
      command_parser&.call(commands)
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

  alnums = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  ALNUMS = (alnums + alnums.downcase + '_' + '0123456789').chars.to_ary
  NUMBERS = "0123456789".chars.to_ary
end

class Integer
  def random_alnums
    to_i.times.map { UniversaTools::ALNUMS.sample }.join('')
  end

  def random_digits
    to_i.times.map { UniversaTools::NUMBERS.sample }.join('')
  end

  def random_bytes
    to_i.times.map { rand(256).chr }.join('').force_encoding('binary')
  end
end


