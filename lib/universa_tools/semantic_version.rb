module UniversaTools
  class SemanticVersion
    attr :parts
    include Comparable

    def initialize string
      @parts = string.split('.').map(&:to_i)
      @parts.any? { |x| x < 0 } and raise ArgumentError, "version numbers must be positive"
    end

    def <=> other
      if other.is_a?(SemanticVersion)
        n = [@parts.size, other.parts.size].max
        (0...n).each { |i|
          my = @parts[i] || -1
          his = other.parts[i] || -1
          return my <=> his if my != his
        }
        0
      else
        self <=> SemanticVersion.new(other)
      end
    end

    def to_s
      @str ||= parts.join('.')
    end
  end
end
