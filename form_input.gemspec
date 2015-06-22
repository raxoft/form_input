# Gem specification.

require File.expand_path( '../lib/form_input/version', __FILE__ )

Gem::Specification.new do |s|
  s.name        = 'form_input'
  s.version     = FormInput::Version::STRING.dup
  s.summary     = 'Form helper which sanitizes, transforms, and validates web request input.'
  s.description = <<EOT
This gem allows you to describe your forms using a simple DSL
and then takes care of sanitizing, transforming and validating the input for you,
providing you with the ready-to-use input in a hash-like structure.
Also includes support for creating URLs containing the form values
as well as handy accessors for building the forms in a templating engine of your choice.
EOT

  s.author      = 'Patrik Rak'
  s.email       = 'patrik@raxoft.cz'
  s.homepage    = 'http://rubygems.org/gems/form_input'
  s.license     = 'MIT'

  s.files       = `git ls-files`.split( "\n" )

  s.add_runtime_dependency 'rack' # FIXME: version?
  s.add_development_dependency 'bacon', '~> 1.2'
end

# EOF #
