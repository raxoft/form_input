# Gem specification.

require File.expand_path( '../lib/form_input/version', __FILE__ )

Gem::Specification.new do |s|
  s.name        = 'form_input'
  s.version     = FormInput::Version::STRING + '.pre1'
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

  s.files       = `git ls-files`.split( "\n" )

  s.required_ruby_version = '>= 2.0.0'
  s.add_runtime_dependency 'rack', '~> 1.5'
  s.add_development_dependency 'bacon', '~> 1.2'
  s.add_development_dependency 'r18n-core', '~> 2.0'
end

# EOF #
