# R18n localization support.

require 'r18n-core'

class FormInput

  include R18n::Helpers
  
  class Parameter
    include R18n::Helpers
    
    # Localized version of error message formatting. See original implementation for details.
    def format_error_message( msg, count = nil, singular = nil, plural = "#{singular}s" )
      return super unless msg.is_a?( Symbol ) and r18n
      if limit = count and singular
        limit = t.form_input.units[ singular, count ].to_s
      end
      text = t.form_input.errors[ msg, *limit ]
      super( text )
    end
    
    # Automatically attempt to translate available parameter options.
    def []( name )
      if form and opts[ name ].is_a?( String ) and r18n
        text = t.forms[ form.class.translation_name ][ self.name ][ name ]
        return text.to_s if text.translated?
      end
      super
    end
    
  end
  
  # Get path to R18n translations provided by this gem.
  def self.translations_path
    File.expand_path( "#{__FILE__}/../r18n" )
  end
  
  # Get name of the form used as translation scope for text translations.
  def self.translation_name
    name.split( '::' ).last
    .gsub( /([A-Z]+)([A-Z][a-z])/, '\1_\2' )
    .gsub( /([a-z\d])([A-Z])/, '\1_\2' )
    .downcase
  end

end

# EOF #
