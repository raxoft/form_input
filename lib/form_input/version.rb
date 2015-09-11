# Version number.

class FormInput
  module Version
    MAJOR = 0
    MINOR = 1
    PATCH = 1
    STRING = [ MAJOR, MINOR, PATCH ].join( '.' ).freeze
  end
end

# EOF #
