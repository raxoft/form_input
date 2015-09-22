# R18n localization support.

require 'r18n-core'

class FormInput

  # Include R18n helpers in form context.
  include R18n::Helpers

  # Localize few parameter methods.
  class Parameter

    # Include R18n helpers in parameter context.
    include R18n::Helpers

    # R18n specific methods.
    module R18nMethods

      # Parameter options which are known to be not localized.
      UNLOCALIZED_OPTIONS = [
        :required, :disabled, :array, :hash, :type, :data, :tag, :tags, :filter, :transform, :format, :class, :check, :test, :reject, :match,
        :min_key, :max_key, :match_key, :min_count, :max_count, :min, :max, :inf, :sup, :min_size, :max_size, :min_bytesize, :max_bytesize,
      ]

      # Automatically attempt to translate available parameter options.
      def []( name )
        if form and r18n
          value = opts[ name ]
          if value.is_a?( String ) or ( value.nil? and not UNLOCALIZED_OPTIONS.include?( name ) )
            text = pt( name )
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
      # Supports both ft.name( args ) and ft( :name, args ) forms.
      def ft( *args )
        form.ft( *args )
      end

      # Like t helper, except that the translation is looked up in the forms.<form_name>.<param_name> scope.
      # Supports both pt.name( args ) and pt( :name, args ) forms. The latter automatically adds self as last argument to support inflection.
      def pt( *args )
        translation = ft[ name ]
        args.empty? ? translation : translation[ *args, self ]
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

  # Localize few step methods.
  module StepMethods

    # Get name of current or given step, if any.
    def step_name( step = self.step )
      name = raw_step_name( step )
      name = ( ft.steps[ step ] | name ).to_s if r18n and name
      name
    end

    # Get hash of steps along with their names.
    def step_names
      hash = raw_step_names
      hash = Hash[ hash.map{ |k,v| [ k, ( ft.steps[ k ] | v ).to_s ] } ] if r18n
      hash
    end

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
  # Supports both ft.name( args ) and ft( :name, args ) forms.
  def ft( *args )
    # If you get a crash here, you forgot to set the locale with R18n.set('en') or similar. No locale, no helper. Sorry.
    translation = t.forms[ self.class.translation_name ]
    args.empty? ? translation : translation[ *args ]
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
    inflection = case param = params.last
    when Parameter
      param.inflection
    when String
      param
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

  # Add our translations as R18n extensions.
  R18n.extension_places << R18n::Loader::YAML.new( translations_path )

  # Localize the helper for boolean args.
  BOOL_ARGS[ :data ] = ->{ [ [ true, r18n ? t.yes.to_s : 'Yes' ], [ false, r18n ? t.no.to_s : 'No' ] ] }

end

# EOF #
