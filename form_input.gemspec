# Gem specification.

require File.expand_path( '../lib/form_input/version', __FILE__ )

Gem::Specification.new do |s|
  s.name        = 'form_input'
  s.version     = FormInput::Version::STRING
  s.summary     = 'Form helper which sanitizes, transforms, validates and encapsulates web request input.'
  s.description = <<EOT
This gem allows you to describe your forms using a simple DSL
and then takes care of sanitizing, transforming, and validating the input for you,
providing you with the ready-to-use input in a model-like structure.
Both simple forms as well as multi-step forms are supported.
Includes handy accessors for automatically building the forms
and reporting error messages using a templating engine of your choice.
Localization support with builtin inflection rules can be enabled, too.
EOT

  s.author      = 'Patrik Rak'
  s.email       = 'patrik@raxoft.cz'
  s.homepage    = 'https://github.com/raxoft/form_input'
  s.license     = 'MIT'

  s.files       = %w[ LICENSE README.md CHANGELOG.md Rakefile .yardopts form_input.gemspec ] + Dir[ '{lib,test,example}/**/*.{rb,yml,txt,slim}' ]

  s.required_ruby_version = '>= 2.1.0'
  s.add_runtime_dependency 'rack', '>= 1.5', '< 4.0'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'bacon', '~> 1.2'
  s.add_development_dependency 'simplecov', '~> 0.21'
  s.add_development_dependency 'rack-test', '>= 1.0', '< 3.0'
  s.add_development_dependency 'r18n-core', '~> 5.0'
end

# EOF #
