module UniversaTools

  class UNS

    # reduce string to its glyph archetypes removing any homological similarities and ambiguity
    #
    # @param [String] name to reduce
    # @return [String] reduced name
    # @raise [ArgumentError] if name contains unprocessable characters
    def self.reduce(name)
      # step 1: remove space and punctuation, step 2: NFKD
      name = name.downcase.strip.gsub(/([-_=+()*&^%#@±§~`<,>\/?'";:{}\[\]"']|\s)+/, '_').unicode_normalize(:nfkd)
      # step 3: XLAT1: removing composing characters and ligatures
      name = name.chars.map { |x| xlat1[x] || x }.join('')
      # step 4: reduce to glyph archetype
      name.chars.map { |ch|
        xlat2[ch] or raise ArgumentError, "illegal character: #{ch.ord}:'#{ch}' in #{name.inspect}"
      }.join('')
    end

    def self.xlat1
      @xlat1 ||= read_xlat(DEFAULT_XLAT1, '')
    end

    def self.xlat2
      @xlat2 ||= read_xlat(DEFAULT_XLAT2, :self)
    end

    private

    def self.decode(char)
      char.strip!
      if char.start_with?('U+')
        code = char[2..].to_i(16)
        [code, code.chr(Encoding::UTF_8)]
      else
        [char.ord, char]
      end
    end

    def self.read_xlat(xlat, missing = '')
      xlat.lines.reduce({}) { |all, line|
        begin
          line = line.split('#', 2)[0].strip
          if line != ''
            left, right = line.split(/\s+/)
            case left
             when /^(.+):(.+)$/
              # range
              start, stop = decode($1), decode($2)
              (start[0]..stop[0]).each { |code|
                ch = code.chr(Encoding::UTF_8)
                all[ch] = right || (missing == :self ? ch : missing)
              }
            when /^(?!U\+)/
              # sequence characters or single character
              left.chars.each { |ch|
                all[ch] = right || (missing == :self ? ch : missing)
              }
            else
              # single character un U+00000 form
              right ||= (missing == :self ? left : right)
              all[decode(left)[1]] = right
            end
          end
        rescue Exception
          puts "Error in line: #{line.inspect}: #{$!}"
          raise
        end
        all
      }
    end

  end
end

#
# Composing characters and ligatures
DEFAULT_XLAT1 = <<END
# Combining diacritical marks, see https://en.wikipedia.org/wiki/Combining_Diacritical_Marks

U+0300:U+033C
U+033D          x
U+033E:U+0362
U+0363          a
U+0364          e
U+0365          i
U+0366          o
U+0367          u
U+0368          c
U+0369          d
U+036A          h
U+036B          m
U+036C          r
U+036D          t
U+036E          v
U+036F          x

#
# replacing ligatures ------------------------
#

ꜳ            aa
æ            ae
ꜵ           ao
ꜷ           au
ꜹ           av
ꜻ           av
ꜽ           ay
U+1F670     et
ﬀ           ff
ﬃ          ffi
ﬄ          ffl
ﬁ           phi
ﬂ           fl
œ           oe
ꝏ          oo
ß           ss
ﬆ           st
ﬅ           st
ꜩ           tz
ᵫ           ue
ꝡ           vy

END

#
# Glyph archetypes
#
DEFAULT_XLAT2 = <<END

# Cyrillic letters

а a
б b

в b  # May be similar in uppercase

г 2  # In some fonts. RFC!
д
е e
ж x
з 3
и v
к k
л
м m
н h
о 0
п
р p
с c
т t
у y
ф
х x
ц
ч 4
ш
щ ш
ьъ b
ы bi
э 3
ю io
я

#
# English correcting similar-looking glyphs
#

# first init all with self, for simplicity:
a:z
0:9

# Now replace similar glyphs to archetypes:

il1|! 1
o0ø   0
u     v
w     vv
$s    5
b     6

# Punctuation placeholder:
_

# Cluster delimiter
.

END