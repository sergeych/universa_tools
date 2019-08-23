require 'optparse'
require 'ostruct'
require 'ansi/code'
require 'universa'
require 'universa_tools'

include Universa

# Show help it nothing to do
ARGV << "-h" if ARGV == []


class Uniring

  class << self
    extend Forwardable
    def_delegators :instance, *SingletonKlass.instance_methods(false)
  end

end