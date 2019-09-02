# UniversaTools

The set of command-line tools and utility classes to simplify using Universa blockchain
in ruby projects. Alfa stagem see usage section below for features by state.

## Why not universa gem?

This workw was split from universa gem because of its lightweight nature allowing
easy, painless upgrades, unlike huge universa gem that causes few megs of universa core
libraries to be reinstalled on each release. Therefore, we limit releases
of [universa gem] to the universa core and adapters updates, and put most of work in porgres
in this lightweight gem.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'universa_tools'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install universa_tools

## Usage

Please see [online docs], the following are ready to beta test:

- [KeyRing](https://kb.universablockchain.com/system/static/gem_universa_tools/UniversaTools/KeyRing.html)

### Command line tools:

When the gem is installed, get tools help with the terminal:

    uctool -h    
    uniring -h

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/universa_tools. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct below.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

We have simplified it and on focus the development not social networking.

Everyone interacting in the UniversaTools project’s codebase, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/universa_tools/blob/master/CODE_OF_CONDUCT.md).

[universa gem]:https://github.com/sergeych/universa
[online docs]:https://kb.universablockchain.com/system/static/gem_universa_tools