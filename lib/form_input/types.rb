# Common form types.

require 'time'
require 'date'

# Extend forms with arguments for form parameter types which are used often.
class FormInput

  # Regular expressions commonly used to validate input arguments.

  # Matches names using latin alphabet.
  LATIN_NAMES_RE = /\A[\p{Latin}\-\. ]+\z/u

  # Matches common email addresses. Note that it doesn't match all addresses allowed by RFC, though.
  SIMPLE_EMAIL_RE = /\A[-_.=+%a-z0-9]+@(?:[-_a-z0-9]+\.)+[a-z]{2,4}\z/i

  # Matches generic ZIP code. Note that the real format changes for each country.
  ZIP_CODE_RE = /\A[A-Z\d]++(?:[- ]?[A-Z\d]+)*+\z/i

  # Filter for phone numbers.
  PHONE_NUMBER_FILTER = ->{ gsub( /\s*[-\/\.]\s*/, '-' ).gsub( /\s+/, ' ' ).strip }

  # Matches generic phone number.
  PHONE_NUMBER_RE = /\A\+?\d++(?:[- ]?(?:\d+|\(\d+\)))*+(?:[- ]?[A-Z\d]+)*+\z/i

  # Basic types.

  # Integer number.
  INTEGER_ARGS = {
    filter: ->{ ( Integer( self, 10 ) rescue self ) unless empty? },
    class: Integer,
  }

  # Float number.
  FLOAT_ARGS = {
    filter: ->{ ( Float( self ) rescue self ) unless empty? },
    class: Float,
  }

  # Boolean value, displayed as a select menu.
  BOOL_ARGS = {
    type: :select,
    data: [ [ true, 'Yes' ], [ false, 'No' ] ],
    filter: ->{ self == 'true' unless empty? },
    class: [ TrueClass, FalseClass ],
  }

  # Boolean value, displayed as a checkbox.
  CHECKBOX_ARGS = {
    type: :checkbox,
    filter: ->{ not empty? },
    format: ->{ self if self },
    class: [ TrueClass, FalseClass ],
  }

  # Address fields.

  # Email.
  EMAIL_ARGS = {
    match: SIMPLE_EMAIL_RE,
  }

  # Zip code.
  ZIP_ARGS = {
    match: ZIP_CODE_RE,
  }

  # Phone number.
  PHONE_ARGS = {
    filter: PHONE_NUMBER_FILTER,
    match: PHONE_NUMBER_RE,
  }

  # Date and time.

  # Full time format.
  TIME_FORMAT = "%Y-%m-%d %H:%M:%S".freeze
  # Full time format example.
  TIME_FORMAT_EXAMPLE = "YYYY-MM-DD HH:MM:SS".freeze

  # Full time.
  TIME_ARGS = {
    placeholder: TIME_FORMAT_EXAMPLE,
    filter: ->{ ( FormInput.parse_time( self, TIME_FORMAT ) rescue DateTime.parse( self ).to_time rescue self ) unless empty? },
    format: ->{ utc.strftime( TIME_FORMAT ) rescue self },
    class: Time,
  }

  # US date format.
  US_DATE_FORMAT = "%m/%d/%Y".freeze
  # US date format example.
  US_DATE_FORMAT_EXAMPLE = "MM/DD/YYYY".freeze

  # Time in US date format.
  US_DATE_ARGS = {
    placeholder: US_DATE_FORMAT_EXAMPLE,
    filter: ->{ ( FormInput.parse_time( self, US_DATE_FORMAT ) rescue DateTime.parse( self ).to_time rescue self ) unless empty? },
    format: ->{ utc.strftime( US_DATE_FORMAT ) rescue self },
    class: Time,
  }

  # UK date format.
  UK_DATE_FORMAT = "%d/%m/%Y".freeze
  # UK date format example.
  UK_DATE_FORMAT_EXAMPLE = "DD/MM/YYYY".freeze

  # Time in UK date format.
  UK_DATE_ARGS = {
    placeholder: UK_DATE_FORMAT_EXAMPLE,
    filter: ->{ ( FormInput.parse_time( self, UK_DATE_FORMAT ) rescue DateTime.parse( self ).to_time rescue self ) unless empty? },
    format: ->{ utc.strftime( UK_DATE_FORMAT ) rescue self },
    class: Time,
  }

  # EU date format.
  EU_DATE_FORMAT = "%-d.%-m.%Y".freeze
  # EU date format example.
  EU_DATE_FORMAT_EXAMPLE = "D.M.YYYY".freeze

  # Time in EU date format.
  EU_DATE_ARGS = {
    placeholder: EU_DATE_FORMAT_EXAMPLE,
    filter: ->{ ( FormInput.parse_time( self, EU_DATE_FORMAT ) rescue DateTime.parse( self ).to_time rescue self ) unless empty? },
    format: ->{ utc.strftime( EU_DATE_FORMAT ) rescue self },
    class: Time,
  }

  # Hours format.
  HOURS_FORMAT = "%H:%M".freeze
  # Hours format example.
  HOURS_FORMAT_EXAMPLE = "HH:MM".freeze

  # Seconds since midnight in hours:minutes format.
  HOURS_ARGS = {
    placeholder: HOURS_FORMAT_EXAMPLE,
    filter: ->{ ( FormInput.parse_time( self, HOURS_FORMAT ).to_i % 86400 rescue self ) unless empty? },
    format: ->{ Time.at( self ).utc.strftime( HOURS_FORMAT ) rescue self },
    class: Integer,
  }

  # Parse time like Time#strptime but raise on trailing garbage.
  # Also ignores -, _ and ^ % modifiers, so the same format can be used for both parsing and formatting.
  def self.parse_time( string, format )
    format = format.gsub( /%[-_^]?(.)/, '%\1' )
    # Rather than using _strptime and checking the leftover field,
    # add required trailing character to both the string and format parameters.
    suffix = ( string[ -1 ] == "\1" ? "\2" : "\1" )
    time = Time.strptime( "+0000 #{string}#{suffix}", "%z #{format}#{suffix}" )
  end

  # Transformation which drops empty values from hashes and arrays and turns empty string into nil.
  PRUNED_ARGS = {
    transform: ->{
      case self
      when Array
        reject{ |v| v.nil? or ( v.respond_to?( :empty? ) && v.empty? ) }
      when Hash
        reject{ |k,v| v.nil? or ( v.respond_to?( :empty? ) && v.empty? ) }
      when String
        self unless empty?
      else
        self
      end
    }
  }

end

# EOF #
