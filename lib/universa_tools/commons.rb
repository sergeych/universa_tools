module UniversaTools

  class MessageException < Exception;
  end

  def error message
    raise MessageException, message
  end

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

end

