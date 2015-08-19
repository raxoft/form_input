# R18n localization support.

require 'r18n-core'

class FormInput

  include R18n::Helpers
  
  class Parameter

    include R18n::Helpers

    # R18n specific methods.
    module R18nMethods

      # Parameter options known to be often localized.
      LOCALIZED_OPTIONS = [ :msg, :match_msg, :reject_msg, :required_msg ]

      # Automatically attempt to translate available parameter options.
      def []( name )
        if form and r18n
          if opts[ name ].is_a?( String ) or LOCALIZED_OPTIONS.include?( name )
            text = pt[ name, self ]
            return text.to_s if text.translated?
          end
        end
        super
      end
      
      # Localized version of error message formatting. See original implementation for details.
      def format_error_message( msg, count = nil, singular = nil, *rest )
        return super unless msg.is_a?( Symbol ) and r18n
        if limit = count and singular
          limit = t.form_input.units[ singular, count ].to_s
        end
        text = t.form_input.errors[ msg, *limit, self ]
        super( text )
      end
      
      # Like t helper, except that the translation is looked up in the forms.<form_name> scope.
      def ft
        form.ft
      end
      
      # Like t helper, except that the translation is looked up in the forms.<form_name>.<param_name> scope.
      def pt
        ft[ name ]
      end
      
    end
    
    include R18nMethods
    
  end
  
  # Get path to R18n translations provided by this gem.
  def self.translations_path
    File.expand_path( "#{__FILE__}/../r18n" )
  end
  
  # Get name of the form used as translation scope for text translations.
  def self.translation_name
    @translation_name ||= name.split( '::' ).last
      .gsub( /([A-Z]+)([A-Z][a-z])/, '\1_\2' )
      .gsub( /([a-z\d])([A-Z])/, '\1_\2' )
      .downcase
  end
  
  # Like t helper, except that the translation is looked up in the forms.<form_name> scope.
  def ft
    t.forms[ self.class.translation_name ]
  end

end

# EOF #
