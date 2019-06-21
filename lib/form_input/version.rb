# Version number.

class FormInput
  module Version
    MAJOR = 1
    MINOR = 2
    PATCH = 0
    STRING = [ MAJOR, MINOR, PATCH ].join( '.' ).freeze
  end
end

# EOF #
