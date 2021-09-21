
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "universa_tools/version"

Gem::Specification.new do |spec|
  spec.name          = "universa_tools"
  spec.version       = UniversaTools::VERSION
  spec.authors       = ["sergeych"]
  spec.email         = ["real.sergeych@gmail.com"]

  spec.summary       = %q{Universa blockchain tools}
  spec.description   = %q{Extended command line and library tools to deal with Universa blockchain.}
  spec.homepage      = "https://github.com/sergeych/universa_tools"
  spec.license       = "MIT"
  spec.required_ruby_version = '>= 2.6'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    # spec.metadata["allowed_push_host"] = "DO: Set to 'http://mygemserver.com'"

    # spec.metadata["homepage_uri"] = spec.homepage
    # spec.metadata["source_code_uri"] = "DO: Put your gem's public repo URL here."
    # spec.metadata["changelog_uri"] = "DO: Put your gem's CHANGELOG.md URL here."
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'universa', ">= 3.12.6.1"
  spec.add_dependency 'ansi'
  spec.add_dependency 'facets'

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.0"
end

