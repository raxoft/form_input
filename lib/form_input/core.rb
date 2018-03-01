# Form input.

# Class for easy form input processing and management.
class FormInput

  # Constants.

  # Default size limit applied to all input.
  DEFAULT_SIZE_LIMIT = 255

  # Default input filter applied to all input.
  DEFAULT_FILTER = ->{ gsub( /\s+/, ' ' ).strip }

  # Minimum hash key value we allow by default.
  DEFAULT_MIN_KEY = 0

  # Maximum hash key value we allow by default.
  DEFAULT_MAX_KEY = ( 1 << 64 ) - 1

  # Encoding we convert all input request parameters into.
  DEFAULT_ENCODING = Encoding::UTF_8

  # Hash mapping error codes to default error messages.
  DEFAULT_ERROR_MESSAGES = {
    required_scalar: "%p is required",
    required_array: "%p are required",
    not_array: "%p are not an array",
    not_hash: "%p are not a hash",
    not_string: "%p is not a string",
    match_key: "%p contain invalid key",
    invalid_key: "%p contain invalid key",
    min_key: "%p contain too small key",
    max_key: "%p contain too large key",
    min_count: "%p must have at least",
    max_count: "%p may have at most",
    value_type: "%p like this is not valid",
    element_type: "%p contain invalid value",
    min_limit: "%p must be at least",
    max_limit: "%p may be at most",
    inf_limit: "%p must be greater than",
    sup_limit: "%p must be less than",
    invalid_encoding: "%p must use valid encoding",
    invalid_characters: "%p may not contain invalid characters",
    min_size: "%p must have at least",
    max_size: "%p may have at most",
    min_bytesize: "%p must have at least",
    max_bytesize: "%p may have at most",
    reject_msg: "%p like this is not allowed",
    match_msg: "%p like this is not valid",
  }

  # Form parameter.
  class Parameter

    # Form this parameter belongs to.
    attr_reader :form

    # Name of the parameter as we use it internally in our code.
    attr_reader :name

    # Name of the parameter as we use it in the form fields and url queries.
    attr_reader :code

    # Additional parameter options.
    attr_reader :opts

    # Initialize new parameter.
    def initialize( name, code, opts )
      @name = name.freeze
      @code = code.freeze
      @opts = opts.freeze
    end

    # Allow copies to evaluate tags again.
    def initialize_dup( other )
      super
      @tags = nil
    end

    # Bind self to given form instance. Can be done only once.
    def bind( form )
      fail "parameter #{name} is already bound" if @form
      @form = form
      self
    end

    # Get the value of this parameter. Always nil for unbound parameters.
    def value
      form ? form[ name ] : nil
    end

    # Format given value for form/URL output, applying the formatting filter as necessary.
    def format_value( value )
      if format.nil? or value.nil? or ( value.is_a?( String ) and type = self[ :class ] and type != String )
        value.to_s
      else
        value.instance_exec( &format ).to_s
      end
    end

    # Get value of this parameter for use in form/URL, with all scalar values converted to strings.
    def form_value
      if array?
        [ *value ].map{ |x| format_value( x ) }
      elsif hash?
        Hash[ [ *value ].map{ |k, v| [ k.to_s, format_value( v ) ] } ]
      else
        format_value( value )
      end
    end

    # Test if given parameter has value of correct type.
    def correct?
      case v = value
      when nil
        true
      when String
        scalar?
      when Array
        array?
      when Hash
        hash?
      end or ( scalar? && [ *self[ :class ] ].any?{ |x| v.is_a?( x ) } )
    end

    # Test if given parameter has value of incorrect type.
    def incorrect?
      not correct?
    end

    # Test if given parameter has blank value.
    def blank?
      case v = value
      when nil
        true
      when String
        v.empty? or !! ( v.valid_encoding? && v =~ /\A\s*\z/ )
      when Array, Hash
        v.empty?
      else
        false
      end
    end

    # Test if given parameter has empty value.
    def empty?
      case v = value
      when nil
        true
      when String, Array, Hash
        v.empty?
      else
        false
      end
    end

    # Test if given parameter has non-empty value.
    def filled?
      not empty?
    end

    # Get the proper name for use in form names, adding [] to array and [key] to hash parameters.
    def form_name( key = nil )
      if array?
        "#{code}[]"
      elsif hash?
        fail( ArgumentError, "missing hash key" ) if key.nil?
        "#{code}[#{key}]"
      else
        code.to_s
      end
    end

    # Test if given value is the selected value, for use in form selects.
    def selected?( value )
      if empty?
        false
      elsif array?
        self.value.include?( value )
      elsif hash?
        false
      else
        self.value == value
      end
    end

    # Get the name of the parameter to be displayed to the user, or nil if there is none.
    def title
      self[ :title ]
    end

    # Get the title for use in form. Fallbacks to normal title and code if no form title was specified.
    def form_title
      self[ :form_title ] || title || code.to_s
    end

    # Get the title for use in error messages. Fallbacks to normal title and code if no form title was specified.
    def error_title
      self[ :error_title ] || title || code.to_s
    end

    # Get list of errors reported for this paramater. Always empty for unbound parameters.
    def errors
      form ? form.errors_for( name ) : []
    end

    # Get first error reported for this parameter. Always nil for unbound parameters.
    def error
      errors.first
    end

    # Test if this parameter had no errors reported.
    def valid?
      errors.empty?
    end

    # Test if this parameter had some errors reported.
    def invalid?
      not valid?
    end

    # Test if the parameter is required.
    def required?
      !! self[ :required ]
    end

    # Test if the parameter is optional.
    def optional?
      not required?
    end

    # Test if the parameter is disabled.
    def disabled?
      !! self[ :disabled ]
    end

    # Test if the parameter is enabled.
    def enabled?
      not disabled?
    end

    # Get type of the parameter. Defaults to :text.
    def type
      self[ :type ] || :text
    end

    # Test if the parameter is hidden.
    def hidden?
      type == :hidden
    end

    # Test if the parameter is to be ignored on output.
    def ignored?
      type == :ignore
    end

    # Test if the parameter is visible.
    def visible?
      not ( hidden? || ignored? )
    end

    # Test if this is an array parameter.
    def array?
      !! self[ :array ]
    end

    # Test if this is a hash parameter.
    def hash?
      !! self[ :hash ]
    end

    # Test if this is a scalar parameter.
    def scalar?
      not ( array? || hash? )
    end

    # Get list of tags of this parameter.
    def tags
      @tags ||= [ *self[ :tag ], *self[ :tags ] ]
    end

    # Test if the parameter is tagged with some of given tags, or any tag if the argument list is empty.
    def tagged?( *tags )
      t = self.tags
      if tags.empty?
        not t.empty?
      else
        tags.flatten.any?{ |x| t.include? x }
      end
    end

    # Test if the parameter is not tagged with any of given tags, or any tag if the argument list is empty.
    def untagged?( *tags )
      not tagged?( *tags )
    end

    # Get input filter for this paramater, if any.
    def filter
      opts[ :filter ]
    end

    # Get input transform for this paramater, if any.
    def transform
      opts[ :transform ]
    end

    # Get output filter for this paramater, if any.
    def format
      opts[ :format ]
    end

    # Get data relevant for this parameter, if any. Returns empty array if there are none.
    def data
      self[ :data ] || []
    end

    # Methods affected by localization, put in separate module for easier overloading.
    module LocaleMethods

      # Get value of arbitrary option. Automatically resolves call blocks.
      def []( name )
        o = opts[ name ]
        o = instance_exec( &o ) if o.is_a?( Proc )
        o
      end

      # Format the error report message. Default implementation includes simple pluralizer.
      # String %p in the message is automatically replaced with error title.
      # Can be redefined to provide correctly localized error messages.
      def format_error_message( msg, count = nil, singular = nil, plural = "#{singular}s" )
        msg = DEFAULT_ERROR_MESSAGES[ msg ] || msg.to_s
        msg += " #{count}" if count
        msg += " #{ count == 1 ? singular : plural }" if singular
        msg.gsub( '%p', error_title )
      end

      # Report an error concerning this parameter.
      # String %p in the message is automatically replaced with error title.
      # In case of multiple errors, the message is added to the end of the list, making it less important than the other errors.
      # Returns self for chaining.
      def report( msg, *args )
        form.report( name, format_error_message( msg, *args ) ) if form
        self
      end

      # Report an error concerning this parameter.
      # String %p in the message is automatically replaced with error title.
      # In case of multiple errors, the message is added to the beginning of the list, making it more important than the other errors.
      # Returns self for chaining.
      def report!( msg, *args )
        form.report!( name, format_error_message( msg, *args ) ) if form
        self
      end

    end

    include LocaleMethods

    # Validation.

    # Validate this parameter. Does nothing if it was found invalid already.
    def validate
      return if invalid?

      # First of all, make sure required parameters are present and not empty.

      if required? && empty?
        report( self[ :required_msg ] || ( scalar? ? :required_scalar : :required_array ) )
        return
      end

      # Otherwise empty parameters are considered correct, as long as the type is correct.

      return if empty? && correct?

      # Make sure the parameter value contains only valid data.

      return unless if array?
        validate_array( value )
      elsif hash?
        validate_hash( value )
      else
        validate_value( value )
      end

      # Finally, invoke the custom check callback if there is any.

      if check = opts[ :check ]
        instance_exec( &check )
      end
    end

    private

    # Validate given array.
    # Return true if the entire array validated correctly, nil or false otherwise.
    def validate_array( value )

      # Make sure it's an array in the first place.

      unless value.is_a? Array
        report( :not_array )
        return
      end

      # Enforce array limits.

      return unless validate_count( value )

      # Now validate array elements. If we detect problems, don't bother with the rest.

      value.all?{ |v| validate_value( v ) }
    end

    # Validate given hash.
    # Return true if the entire hash validated correctly, nil or false otherwise.
    def validate_hash( value )

      # Make sure it's a hash in the first place.

      unless value.is_a? Hash
        report( :not_hash )
        return
      end

      # Enforce hash limits.

      return unless validate_count( value )

      # Now validate hash keys and values. If we detect problems, don't bother with the rest.

      value.all?{ |k, v| validate_key( k ) && validate_value( v ) }
    end

    # Validate given hash key.
    # Return true if it validated correctly, nil or false otherwise.
    def validate_key( value )

      # If there is a key pattern specified, make sure the key matches.

      if patterns = self[ :match_key ]
        unless [ *patterns ].all?{ |x| value.to_s =~ x }
          report( :match_key )
          return
        end
        return true
      end

      # Otherwise make sure it's an integer.

      unless value.is_a? Integer
        report( :invalid_key )
        return
      end

      # Make sure it is within allowed limits.

      if limit = self[ :min_key ] and value < limit
        report( :min_key )
        return
      end

      if limit = self[ :max_key ] and value > limit
        report( :max_key )
        return
      end

      true
    end

    # Validate container limits.
    # Return true if it validated correctly, nil or false otherwise.
    def validate_count( value )

      if limit = self[ :min_count ] and value.count < limit
        report( :min_count, limit, 'element' )
        return
      end

      if limit = self[ :max_count ] and value.count > limit
        report( :max_count, limit, 'element' )
        return
      end

      true
    end

    # Validate given scalar value.
    # Return true if it validated correctly, nil or false otherwise.
    def validate_value( value )

      # First apply the type tests.

      if type = self[ :class ] and type != String
        unless [ *type ].any?{ |x| value.is_a?( x ) }
          report( scalar? ? :value_type : :element_type )
          return
        end
      else
        return unless validate_string( value )
      end

      # Then enforce any value limits.

      if limit = self[ :min ] and value.to_f < limit.to_f
        report( :min_limit, limit )
        return
      end

      if limit = self[ :max ] and value.to_f > limit.to_f
        report( :max_limit, limit )
        return
      end

      if limit = self[ :inf ] and value.to_f <= limit.to_f
        report( :inf_limit, limit )
        return
      end

      if limit = self[ :sup ] and value.to_f >= limit.to_f
        report( :sup_limit, limit )
        return
      end

      # Finally, invoke the custom callback if there is any.

      if test = opts[ :test ]
        instance_exec( value, &test )
        return unless valid?
      end

      true
    end

    # Validate given string.
    # Return true if it validated correctly, nil or false otherwise.
    def validate_string( value )

      # Make sure it's a string in the first place.

      unless value.is_a? String
        report( scalar? ? :not_string : :element_type )
        return
      end

      # Make sure the string contains only valid data.

      unless value.valid_encoding? && ( value.encoding == DEFAULT_ENCODING || value.ascii_only? )
        report( :invalid_encoding )
        return
      end

      unless value =~ /\A(\p{Graph}|[ \t\r\n])*\z/u
        report( :invalid_characters )
        return
      end

      # Enforce any size limits.

      if limit = self[ :min_size ] and value.size < limit
        report( :min_size, limit, 'character' )
        return
      end

      if limit = self[ :min_bytesize ] and value.bytesize < limit
        report( :min_bytesize, limit, 'byte' )
        return
      end

      if limit = self[ :max_size ] and value.size > limit
        report( :max_size, limit, 'character' )
        return
      end

      if limit = self[ :max_bytesize ] and value.bytesize > limit
        report( :max_bytesize, limit, 'byte' )
        return
      end

      # Finally make sure the format is valid.

      if patterns = self[ :reject ]
        if [ *patterns ].any?{ |x| value =~ x }
          report( self[ :reject_msg ] || self[ :msg ] || :reject_msg )
          return
        end
      end

      if patterns = self[ :match ]
        unless [ *patterns ].all?{ |x| value =~ x }
          report( self[ :match_msg ] || self[ :msg ] || :match_msg )
          return
        end
      end

      true
    end

  end

  # Class methods.

  class << self

    # Create standalone copy of form parameters in case someone inherits an existing form.
    def inherited( into )
      into.instance_variable_set( '@params', form_params.dup )
    end

    # Get hash mapping parameter names to parameters themselves.
    def form_params
      @params ||= {}
    end

    # Get given parameter(s), hash style.
    def []( *names )
      if names.count == 1
        form_params[ names.first ]
      else
        form_params.values_at( *names )
      end
    end

    # Add given parameter to the form, after performing basic validity checks.
    def add( param )
      name = param.name

      fail ArgumentError, "duplicate parameter #{name}" if form_params[ name ]
      fail ArgumentError, "invalid parameter name #{name}" if method_defined?( name )

      self.send( :attr_accessor, name )

      form_params[ name ] = param
    end
    private :add

    # Copy given/all form parameters.
    # Returns self for chaining.
    def copy( source, opts = {} )
      case source
      when Parameter
        add( Parameter.new(
          opts[ :name ] || source.name,
          opts[ :code ] || opts[ :name ] || source.code,
          source.opts.merge( opts )
        ) )
      when Array
        source.each{ |x| copy( x, opts ) }
      when Class
        fail ArgumentError, "invalid source form #{source.inspect}" unless source < FormInput
        copy( source.form_params.values, opts )
      else
        fail ArgumentError, "invalid source parameter #{source.inspect}"
      end
      self
    end

    # Define form parameter with given name, code, title, maximum size, options, and filter block.
    # All fields except name are optional. In case the code is missing, name is used instead.
    # If no size limits are specified, 255 characters and bytes limits are applied by default.
    # If no filter is explicitly defined, default filter squeezing and stripping whitespace is applied.
    # Returns self for chaining.
    def param( name, *args, &block )

      # Fetch arguments.

      code = name
      code = args.shift if args.first.is_a? Symbol

      title = args.shift if args.first.is_a? String

      size = args.shift if args.first.is_a? Numeric

      opts = {}
      opts.merge!( args.shift ) while args.first.is_a? Hash

      fail ArgumentError, "invalid arguments #{args}" unless args.empty?

      # Set the title.

      opts[ :title ] = title.freeze if title

      # Set input filter.

      opts[ :filter ] = block if block
      opts[ :filter ] = DEFAULT_FILTER unless opts.key?( :filter )

      # Enforce default size limits for any input processed.

      limit = DEFAULT_SIZE_LIMIT

      size = ( opts[ :max_size ] ||= size || limit )
      opts[ :max_bytesize ] ||= limit if size.is_a?( Proc ) or size <= limit

      # Set default key limits for hash parameters.

      if opts[ :hash ]
        opts[ :min_key ] ||= DEFAULT_MIN_KEY
        opts[ :max_key ] ||= DEFAULT_MAX_KEY
      end

      # Define parameter.

      add( Parameter.new( name, code, opts ) )
      self
    end

    # Like param, except this defines required parameter.
    def param!( name, *args, &block )
      param( name, *args, required: true, &block )
    end

    # Like param, except that it defines array parameter.
    def array( name, *args, &block )
      param( name, *args, array: true, &block )
    end

    # Like param!, except that it defines required array parameter.
    def array!( name, *args, &block )
      param!( name, *args, array: true, &block )
    end

    # Like param, except that it defines hash parameter.
    def hash( name, *args, &block )
      param( name, *args, hash: true, &block )
    end

    # Like param!, except that it defines required hash parameter.
    def hash!( name, *args, &block )
      param!( name, *args, hash: true, &block )
    end

    # Create new form from request with external values.
    def from_request( request )
      new.import( request )
    end

    # Create new form from hash with external values.
    def from_params( params )
      new.import( params )
    end

    # Create new form from hash with internal values.
    def from_hash( hash )
      new.set( hash )
    end

  end

  # Instantiation and access.

  # Get copy of parameter hash with parameters bound to this form.
  def bound_params
    hash = {}
    self.class.form_params.each{ |name, param| hash[ name ] = param.dup.bind( self ) }
    hash.freeze
  end
  private :bound_params

  # Create new form info, initializing it from given hash or request, if anything.
  def initialize( *args )
    @params = bound_params
    @errors = nil
    for arg in args
      if arg.is_a? Hash
        set( arg )
      else
        import( arg )
      end
    end
  end

  # Initialize form clone.
  def initialize_clone( other )
    super
    @params = bound_params
    @errors &&= Hash[ @errors.map{ |k,v| [ k, v.clone ] } ]
  end

  # Initialize form copy.
  def initialize_dup( other )
    super
    @params = bound_params
    @errors = nil
  end

  # Freeze the form.
  def freeze
    unless frozen?
      validate?
      @errors.freeze.each{ |k,v| v.freeze }
    end
    super
  end

  # Import request parameter value.
  def sanitize_value( value, filter = nil )
    case value
    when String
      # Note that Rack does no encoding processing as of now,
      # and even if we know content type charset, the query charset
      # is not well defined and we can't fix the multi-part input here either.
      # So we just hope that all clients will send the data in UTF-8 which we used in the form,
      # and enforce everything to UTF-8. If it is not valid, we keep the binary string instead
      # so the validation can detect it but the user can still process it himself if he wants to.
      value = value.dup.force_encoding( DEFAULT_ENCODING )
      if value.valid_encoding?
        value = value.instance_exec( &filter ) if filter
      else
        value.force_encoding( Encoding::BINARY )
      end
      value
    when Array
      # Arrays are supported, but note that the validation done later only allows flat arrays.
      value.map{ |x| sanitize_value( x, filter ) }
    when Hash
      # To reduce security issues, we prefer integer hash keys only.
      # The validation done later ensures that the keys are valid, within range,
      # and that only flat hashes are allowed.
      Hash[ value.map{ |k, v| [ ( Integer( k, 10 ) rescue k ), sanitize_value( v, filter ) ] } ]
    else
      fail TypeError, "unexpected parameter type"
    end
  end
  private :sanitize_value

  # Import parameter values from given request or hash. Applies parameter input filters and transforms as well.
  # Returns self for chaining.
  def import( request )
    for name, param in @params
      if value = request[ param.code ]
        value = sanitize_value( value, param.filter )
        if transform = param.transform
          value = value.instance_exec( &transform )
        end
        self[ name ] = value
      end
    end
    self
  end

  # Set parameter values from given hash.
  # Returns self for chaining.
  def set( hash )
    for name, value in hash
      self[ name ] = value
    end
    self
  end

  # Clear all/given parameter values. Both names and parameters are accepted.
  # Returns self for chaining.
  def clear( *names )
    names = names.empty? ? params_names : validate_names( names )
    for name in names
      self[ name ] = nil
    end
    self
  end

  # Get given parameter(s) value(s), hash style.
  def []( *names )
    if names.count == 1
      send( names.first )
    else
      names.map{ |x| send( x ) }
    end
  end

  # Set given parameter value, hash style.
  # Unlike setting the attribute directly, this triggers a revalidation in the future.
  def []=( name, value )
    @errors = nil
    send( "#{name}=", value )
  end

  # Return all non-empty parameters as a hash.
  # See also url_params, which creates a hash suitable for url output.
  def to_hash
    result = {}
    filled_params.each{ |x| result[ x.name ] = x.value }
    result
  end
  alias to_h to_hash

  # Convert parameters to names and fail if we encounter unknown one.
  def validate_names( names )
    names.flatten.map do |name|
      name = name.name if name.is_a? Parameter
      fail( ArgumentError, "unknown parameter #{name}" ) unless @params[ name ]
      name
    end
  end
  private :validate_names

  # Create copy of itself, with given parameters unset. Both names and parameters are accepted.
  def except( *names )
    result = dup
    for name in validate_names( names )
      result[ name ] = nil
    end
    result
  end

  # Create copy of itself, with only given parameters set. Both names and parameters are accepted.
  def only( *names )
    # It would be easier to create new instance here and only copy selected values,
    # but we want to use dup instead of new here, as the derived form can use
    # different parameters in its construction.
    result = dup
    for name in params_names - validate_names( names )
      result[ name ] = nil
    end
    result
  end

  # Parameter lists.

  # Get given named parameter.
  def param( name )
    @params[ name ]
  end
  alias parameter param

  # Get list of all parameters.
  def params
    @params.values
  end
  alias parameters params

  # Get list of all parameter names.
  def params_names
    @params.keys
  end
  alias parameters_names params_names

  # Get list of given named parameters.
  # Note that nil is returned for unknown names, and duplicate parameters for duplicate names.
  def named_params( *names )
    @params.values_at( *names )
  end
  alias named_parameters named_params

  # Get list of parameters with correct value types.
  def correct_params
    params.select{ |x| x.correct? }
  end
  alias correct_parameters correct_params

  # Get list of parameters with incorrect value types.
  def incorrect_params
    params.select{ |x| x.incorrect? }
  end
  alias incorrect_parameters incorrect_params

  # Get list of parameters with blank values.
  def blank_params
    params.select{ |x| x.blank? }
  end
  alias blank_parameters blank_params

  # Get list of parameters with empty values.
  def empty_params
    params.select{ |x| x.empty? }
  end
  alias empty_parameters empty_params

  # Get list of parameters with non-empty values.
  def filled_params
    params.select{ |x| x.filled? }
  end
  alias filled_parameters filled_params

  # Get list of required parameters.
  def required_params
    params.select{ |x| x.required? }
  end
  alias required_parameters required_params

  # Get list of optional parameters.
  def optional_params
    params.select{ |x| x.optional? }
  end
  alias optional_parameters optional_params

  # Get list of disabled parameters.
  def disabled_params
    params.select{ |x| x.disabled? }
  end
  alias disabled_parameters disabled_params

  # Get list of enabled parameters.
  def enabled_params
    params.select{ |x| x.enabled? }
  end
  alias enabled_parameters enabled_params

  # Get list of hidden parameters.
  def hidden_params
    params.select{ |x| x.hidden? }
  end
  alias hidden_parameters hidden_params

  # Get list of ignored parameters.
  def ignored_params
    params.select{ |x| x.ignored? }
  end
  alias ignored_parameters ignored_params

  # Get list of visible parameters.
  def visible_params
    params.select{ |x| x.visible? }
  end
  alias visible_parameters visible_params

  # Get list of array parameters.
  def array_params
    params.select{ |x| x.array? }
  end
  alias array_parameters array_params

  # Get list of hash parameters.
  def hash_params
    params.select{ |x| x.hash? }
  end
  alias hash_parameters hash_params

  # Get list of scalar parameters.
  def scalar_params
    params.select{ |x| x.scalar? }
  end
  alias scalar_parameters scalar_params

  # Get list of parameters tagged with given/any tags.
  def tagged_params( *tags )
    params.select{ |x| x.tagged?( *tags ) }
  end
  alias tagged_parameters tagged_params

  # Get list of parameters not tagged with given/any tags.
  def untagged_params( *tags )
    params.select{ |x| x.untagged?( *tags ) }
  end
  alias untagged_parameters untagged_params

  # Get list of parameters with no errors reported.
  def valid_params
    params.select{ |x| x.valid? }
  end
  alias valid_parameters valid_params

  # Get list of parameters with some errors reported.
  def invalid_params
    params.select{ |x| x.invalid? }
  end
  alias invalid_parameters invalid_params

  # Get all/given parameters chunked into individual rows for nicer form display.
  def chunked_params( params = self.params )
    params.chunk{ |p| p[ :row ] || :_alone }.map{ |x,a| a.count > 1 ? a : a.first }
  end

  # URL helpers.

  # Return true if all parameters are empty.
  def empty?
    filled_params.empty?
  end

  # Get hash of all non-empty parameters for use in URL.
  def url_params
    result = {}
    filled_params.each{ |x| result[ x.code ] = x.form_value }
    result
  end
  alias url_parameters url_params

  # Create string containing URL query from all current non-empty parameters.
  def url_query
    Rack::Utils.build_nested_query( url_params )
  end

  # Extend given URL with query created from all current non-empty parameters.
  def extend_url( url )
    url = url.to_s.dup
    query = url_query
    unless query.empty?
      url << ( url['?'] ? '&' : '?' ) << query
    end
    url
  end

  # Build URL from given URL and combination of current paramaters and provided parameters.
  def build_url( url, args = {} )
    dup.set( args ).extend_url( url )
  end

  # Validation.

  # Get hash of all errors detected for each parameter.
  def errors
    validate?
    @errors.dup
  end

  # Get list of error messages, but including only the first one reported for each parameter.
  def error_messages
    errors.values.map{ |x| x.first }
  end

  # Remember error concerning given parameter.
  # In case of multiple errors, the message is added to the end of the list, making it less important than the other errors.
  # Returns self for chaining.
  def report( name, msg )
    validate?
    ( @errors[ name ] ||= [] ) << msg.to_s.dup.freeze
    self
  end

  # Remember error concerning given parameter.
  # In case of multiple errors, the message is added to the beginning of the list, making it more important than the other errors.
  # Returns self for chaining.
  def report!( name, msg )
    validate?
    ( @errors[ name ] ||= [] ).unshift( msg.to_s.dup.freeze )
    self
  end

  # Get list of errors for given parameter. Returns empty list if there were no errors.
  def errors_for( name )
    errors[ name ] || []
  end

  # Get first error for given parameter. Returns nil if there were no errors.
  def error_for( name )
    errors_for( name ).first
  end

  # Test if there were no errors (overall or for given parameters) reported.
  def valid?( *names )
    if names.empty?
      errors.empty?
    else
      validate_names( names ).all?{ |x| errors_for( x ).empty? }
    end
  end

  # Test if there were some errors (overall or for given parameters) reported.
  def invalid?( *names )
    not valid?( *names )
  end

  # Return parameter(s) value(s) as long as they are all valid, nil otherwise.
  def valid( name, *names )
    self[ name, *names ] if valid?( name, *names )
  end

  # Validate parameter values and remember any errors detected.
  # You can override this in your class if you need more specific validation
  # and :check callback is not good enough. Just make sure to call super first.
  # Returns self for chaining.
  def validate
    @errors ||= {}
    params.each{ |x| x.validate }
    self
  end

  # Like validate, except that it forces revalidation of all parameters.
  # Returns self for chaining.
  def validate!
    @errors = {}
    validate
    self
  end

  # Like validate, except that it does nothing if validation was already done.
  # Returns self for chaining.
  def validate?
    validate unless @errors
    self
  end

end

# EOF #
