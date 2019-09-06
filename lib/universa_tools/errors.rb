module UniversaTools

  class MessageException < Exception;
  end

  class CodeException < MessageException
    attr :code

    def initialize code, text = nil
      text ||= code
      @code = code
      super(text)
    end
  end

  class NotFoundException < CodeException
    def initialize object
      super(:file_not_found, "not found: #{object}")
    end
  end

  class InsufficientFundsException < CodeException
    def initialize
      super(:insufficient_funds)
    end
  end

end


