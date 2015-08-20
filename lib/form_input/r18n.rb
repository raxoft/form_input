# R18n localization support.

require 'r18n-core'

class FormInput

  include R18n::Helpers

  class Parameter

    include R18n::Helpers

    # R18n specific methods.
    module R18nMethods

      # Parameter options known to be often localized.
      # Note that :title is intentionally missing - parameter should respond to titled? consistently regardless of locale.
      LOCALIZED_OPTIONS = [ :form_title, :error_title, :msg, :match_msg, :reject_msg, :required_msg, :inflect, :gender, :plural ]

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

      # Get the inflection string used for correctly inflecting the parameter messages.
      # Note that it ignores the noun case as the parameter names are supposed to use the nominative case anyway.
      def inflection
        ( self[ :inflect ] || "#{pluralize}#{gender}" ).to_s
      end

      # Get the string corresponding to the grammatical number of the parameter name used for inflecting the parameter messages.
      def pluralize
        p = self[ :plural ]
        p = ! scalar? if p.nil?
        p = 's' if p == false
        p = 'p' if p == true
        p.to_s
      end

      # Get the gender string used for inflecting the parameter messages.
      def gender
        ( self[ :gender ] || ( t.form_input.default_gender | 'n' ) ).to_s
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

  # Iterate over each possible inflection for given inflection string and return first non-nil result.
  # You may override this if you need more complex inflection fallbacks for some locale.
  def self.find_inflection( string )
    until string.empty?
      break if result = yield( string )
      string = string[0..-2]
    end
    result
  end

  # Define our inflection filter.
  R18n::Filters.add( 'inflect', :inflection ) do |translations, config, *params|
    if param = params.last and param.is_a?( Parameter )
      inflection = param.inflection
    end
    inflection ||= 'sn'
    text = FormInput.find_inflection( inflection ) do |i|
      translations[ i ] if translations.key?( i )
    end
    text || R18n::Translation.new(
      config[ :locale ], config[ :path ],
      locale: config[ :locale ], translations: translations
    )[ inflection ]
  end

end

# EOF #
