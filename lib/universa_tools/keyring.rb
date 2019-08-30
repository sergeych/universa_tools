# require 'universa_tools'

module UniversaTools
  class KeyRing

    def initialize(path, password_proc, generate: false)
      @password_proc = password_proc
      @root_path = File.expand_path(path)
      exists = !File.exist?(@root_path)
      case
        when generate && exists
          error "Can't generate: keyring already exists"
        when generate && !exists
          # TODO: generate
          generate_new()
        when exists
          # TODO: open
        else
          raise NotFoundException.new(path) unless File.exist?(@root_path)
      end
    end

    private

    def get_key
    end

    def generate_new
      File.mkdir_p(@root_path)
      File.chmod(0600, @root_path)
    end

  end
end