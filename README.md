# Form input

[![Gem Version](https://img.shields.io/gem/v/form_input.svg)](http://rubygems.org/gems/form_input) [![Build Status](https://travis-ci.org/raxoft/form_input.svg?branch=master)](http://travis-ci.org/raxoft/form_input) [![Dependency Status](https://img.shields.io/gemnasium/raxoft/form_input.svg)](https://gemnasium.com/raxoft/form_input) [![Code Climate](https://img.shields.io/codeclimate/github/raxoft/form_input.svg)](https://codeclimate.com/github/raxoft/form_input) [![Coverage](https://img.shields.io/codeclimate/coverage/github/raxoft/form_input.svg)](https://codeclimate.com/github/raxoft/form_input)

Form input is a gem which helps dealing with web request input and with the creation of HTML forms.

Install the gem:

``` shell
gem install form_input
```

Describe your forms in a [DSL] like this:

``` ruby
# contact_form.rb
require 'form_input'
class ContactForm < FormInput
  param! :email, "Email address", EMAIL_ARGS
  param! :name, "Name"
  param :company, "Company"
  param! :message, "Message", 1000, type: :textarea, size: 16, filter: ->{ rstrip }
end
```

Then use them in your controllers/route handlers like this:

``` ruby
# app.rb
get '/contact' do
  @form = ContactForm.new
  @form.set( email: user.email, name: user.full_name ) if user?
  slim :contact_form
end

post '/contact' do
  @form = ContactForm.new( request )
  return slim :contact_form unless @form.valid?
  text = @form.params.map{ |p| "#{p.title}: #{p.value}\n" }.join
  sent = Email.send( settings.contact_recipient, text, reply_to: @form.email )
  slim( sent ? :contact_sent : :contact_failed )
end
```

Using them in your templates is as simple as this:

``` slim
// contact_form.slim
.panel.panel-default
  .panel-heading
    = @title = "Contact Form"
  .panel-body
    form *form_attrs
      fieldset
        == snippet :form_panel, params: @form.params
        button.btn.btn-default type='submit' Send
```

The `FormInput` class will take care of sanitizing the input,
converting it into any desired internal representation,
validating it, and making it available in a model-like structure.
The provided template snippets will take care of rendering the form parameters
as well as any errors detected back to the user.
You just get to use the input and control the flow the way you want.
In fact, it's not limited to form input only either -
it can be used with any web request input,
including that of [AJAX] or [REST] API end points.
The gem is completely framework agnostic,
comes with full test coverage,
and even supports multi-step forms and localization out of the box.
Sounds cool enough? Then read on.

## Table of Contents

* [Introduction](#form-input)
* [Table of Contents](#table-of-contents)
* [Form Basics](#form-basics)
  * [Defining Parameters](#defining-parameters)
  * [Internal vs External Representation](#internal-vs-external-representation)
    * [Input Filter](#input-filter)
    * [Output Format](#output-format)
    * [Input Transform](#input-transform)
  * [Array and Hash Parameters](#array-and-hash-parameters)
  * [Reusing Form Parameters](#reusing-form-parameters)
  * [Creating Forms](#creating-forms)
  * [Errors and Validation](#errors-and-validation)
  * [Using Forms](#using-forms)
  * [URL Helpers](#url-helpers)
  * [Form Helpers](#form-helpers)
  * [Extending Forms](#extending-forms)
  * [Parameter Options](#parameter-options)
* [Form Templates](#form-templates)
  * [Form Template](#form-template)
  * [Simple Parameters](#simple-parameters)
  * [Hidden Parameters](#hidden-parameters)
  * [Complex Parameters](#complex-parameters)
    * [Text Area](#text-area)
    * [Select and Multi-Select](#select-and-multi-select)
    * [Radio Buttons](#radio-buttons)
    * [Checkboxes](#checkboxes)
  * [Inflatable Parameters](#inflatable-parameters)
  * [Extending Parameters](#extending-parameters)
  * [Grouped Parameters](#grouped-parameters)
  * [Chunked Parameters](#chunked-parameters)
* [Multi-Step Forms](#multi-step-forms)
  * [Defining Multi-Step Forms](#defining-multi-step-forms)
  * [Multi-Step Form Functionality](#multi-step-form-functionality)
  * [Using Multi-Step Forms](#using-multi-step-forms)
  * [Rendering Multi-Step Forms](#rendering-multi-step-forms)
* [Localization](#localization)
  * [Error Messages and Inflection](#error-messages-and-inflection)
  * [Localizing Forms](#localizing-forms)
  * [Localizing Parameters](#localizing-parameters)
  * [Localization Helpers](#localization-helpers)
  * [Inflection Filter](#inflection-filter)
  * [Localizing Form Steps](#localizing-form-steps)
  * [Supported Locales](#supported-locales)
* [Credits](#credits)

## Form Basics

The following chapters explain how to describe your forms using a [DSL],
what's the difference between internal and external representation,
how to create form instances and how to deal with errors,
and, finally, how to access the form input itself.

And note that while forms get mentioned a lot,
it can be all applied to any other web request input just as well.
Even [AJAX] end points or [REST] API end points
can describe their input and let it have converted and validated for them
by the same means,
which is worth keeping in mind.

### Defining Parameters

To define a form, simply inherit from `FormInput` and then
use the `param` or `param!` methods to define form parameters like this:

``` ruby
require 'form_input'
class MyForm < FormInput
  param! :email, "Email Address"
  param :name, "Full Name"
end
```

The `param` method takes
parameter _name_
and
parameter _title_
as arguments.
The _name_ is how you will address the parameter in your code,
while the optional _title_ is the string which will be displayed to the user by default.

The `param!` method works the same way but creates a required parameter.
Such parameters are required to appear in the input and to have a non-empty value.
Failure to do so will be automatically reported as an error
(discussed further in [Errors and Validation](#errors-and-validation)).

Both methods actually take an optional _options_ as their last argument, too.
The _options_ argument is a hash which is used to control
most aspects of the parameter.
In fact, using the _title_ argument is just a shortcut identical to
setting the parameter option `:title` to the same value.
And using the `param!` method is identical to setting the parameter option `:required` to `true`.
The following two declarations are therefore the same:

``` ruby
  param! :email, "Email Address"
  param :email, title: "Email Address", required: true
```

Parameters support many more parameter options,
and we will discuss each one in turn as we go.
Comprehensive summary for an avid reader is however available in [Parameter Options](#parameter-options).

The value of each parameter is a string by default (or `nil` if the parameter is not set at all).
The string size is implicitly limited to 255 characters and bytes by default.
To limit the size explicitly, you can use an optional _size_ parameter like this:

``` ruby
  param! :title, "Title", 100
```

This limits the string to 100 characters and 255 bytes.
That's because
as long as the character size limit is less than or equal to 255,
the implicit 255 bytes limit is retained.
Such setting is most suitable for strings stored in a database as the `varchar` type.
If the character size limit is greater than 255, no byte size limit is enforced by default.
Such setting is most suitable for strings stored in a database as the `text` type.
Of course, you can set both character and byte size limits yourself like this:

``` ruby
  param :text, "Text", 50000, max_bytesize: 65535
```

This is identical to setting the `:max_size` and `:max_bytesize` options explicitly.
Similarly, there are the `:min_size` and `:min_bytesize` counterparts,
which you can use to limit the minimum sizes like this:

``` ruby
  param :nick, "Nick Name", min_size: 3, max_size: 8
```

The size limits are also often used for passwords.
Those usually use a bit more options, though:

``` ruby
class PasswordForm
  param :password, "Password", min_size: 8, max_size: 16, type: :password,
    filter: ->{ chomp }
end
```

The `:filter` option specifies a code block
which is used to preprocess the incoming string value.
By default, all parameters use a filter which squeezes any whitespace into a single space
and then strips the leading and trailing whitespace entirely.
This way the string input is always nice and clean even if the user types some extra spaces somewhere.
For passwords, though, we want to preserve the characters as they are, including spaces.
We could do that by simply setting the `:filter` option to `nil`.
However, at the same time we want to get rid of the trailing newline character
which is often appended by the browser
when the user cuts and pastes the password from somewhere.
Not doing this would make the password eventually fail for no apparent reason,
resulting in poor user experience.
That's why we use `chomp` as the filter above.
The filter block is executed in the context of the string value itself,
so it actually executes `String#chomp` to strip the trailing newline if present.
More details about filters will follow in the very next chapter
[Internal vs External Representation](#internal-vs-external-representation).

The `:type` option shown above is another common option used often.
The `FormInput` class itself doesn't care much about it,
but it is passed through to the form templates to make the parameter render properly.
Similarly, the `:disabled` option can be used to render the parameter as disabled.
In fact, any parameter option you specify is available in the templates,
so you can pass through arbitrary things like `:subtitle` or `:help`
and use them in the templates any way you like.

It's also worth mentioning that the options
can be evaluated dynamically at runtime.
Simply pass a code block in place of any option value
(except those whose value is already supposed to contain a code block, like `:filter` above)
and it will be called to obtain the actual value.
The block is called in context of the form parameter itself,
so it can access any of its methods and its form's methods easily.
For example, you can let the form automatically disable some fields
based on available user permissions by defining the `is_forbidden?` method accordingly:

``` ruby
  param :avatar, "Avatar",
    disabled: ->{ form.is_forbidden?( :avatar ) }
  param :comment, "Comment", type: :textarea,
    disabled: ->{ form.is_forbidden?( :comment ) }
```

If you happen to use some option arguments often,
you can factor them out and share them like this:

``` ruby
  FEATURED_ARGS = { disabled: ->{ form.is_forbidden?( name ) } }
  param :avatar, "Avatar", FEATURED_ARGS
  param :comment, "Comment", FEATURED_ARGS, type: :textarea
```

This works since you can actually pass several hashes in place of the _options_ argument
and they all get merged together from left to right.
This allows you to mix various options presets together and then tweak them further as needed.

### Internal vs External Representation

Now when you know how to define some parameters,
let's talk about the parameter values a bit.
For this, it is important that you understand
the difference between their internal and external representations.

The internal representation, as you might have guessed,
are the parameter values which you will use in your application.
The external representation is how the parameters are present
to the browser via HTML forms or URLs
and passed back to the server.

Normally, both representations are the same.
The parameters are named the same way in both cases
and their values are strings in both cases, too.
But that doesn't have to be that way.

First of all, it is possible to change the external name of the parameter.
Both `param` and `param!` methods actually accept
an optional _code_ argument,
which can be used like this:

``` ruby
  param! :query, :q, "Query"
```

This lets you call the parameter `query` in your application,
but in forms and URLs it will use its shorter code name `q` instead.
This also comes handy when you need to change the external name for some reason,
but want to retain the internal name which your application uses all over the place.

#### Input Filter

Now the code name was the easy part.
The cool part is that the parameter values can have different
internal and external representations as well.
The external representation is always a string, of course,
but we can choose the internal representation at will.

We have already seen above that each parameter has a `:filter` option
which is used to preprocess the input string the way we want.
If you don't specify any filter explicitly,
the parameter gets an implicit one which cleans up any whitespace in the input string like this:

``` ruby
  filter: ->{ gsub( /\s+/, ' ' ).strip }
```

Note that parameters which are not present in the web request
are never passed through a filter and
simply remain set to their previous value, which is `nil` by default.
The filter therefore only needs to deal with string input values,
not `nil` or anything else.

Of course, the filter can do any string processing you need.
For example, this filter converts typical product keys into their canonic form:

``` ruby
  filter: ->{ gsub( /[\s-]+/, '' ).gsub( /.{5}(?=.)/, '\0-' ).upcase }
```

However, the truth is that the filter doesn't have to return a string.
It can return any object type you want.
For example, here is a naive filter which converts any input string into an integer value:

``` ruby
  filter: ->{ to_i },
  class: Integer
```

The `:class` option is used to tell `FormInput` what kind of object is the filter supposed to return.
When set, it is used to validate the input after the conversion,
and any mismatch is reported as an error.
The option accepts an array of object types, too.
This is handy for example when the filter returns boolean values:

``` ruby
  filter: ->{ self == "true" },
  class: [ TrueClass, FalseClass ]
```

The naive integer filter shown above works fine as long as the input is correct,
but the problem is that it creates integers even from completely incorrect input.
If you want to make sure the user didn't make a typo in their input,
the following filter is more suitable:

``` ruby
  filter: ->{ Integer( self, 10 ) rescue self },
  class: Integer
```

This filter uses more strict conversion which fails in case of invalid input.
In such case the filter uses the `rescue` clause
to keep the original string value intact.
This assures that it can be displayed to the user and edited again to fix it.
This is a really good practice -
making sure that even bad input can round trip back to the user -
so you should stick to it whenever possible.

There is one last thing to take care of - an empty input string.
Whenever the user submits the form without entering anything in the input fields,
the browser sends empty strings to the server as the parameter values.
In this regard an empty string is the same as no input as far as the form is concerned,
so both `nil` value and empty string are considered as valid input for optional parameters.
The `FormInput` normally preserves those values intact so you can distinguish the two cases if you wish.
But in case of the integer conversion it is much more convenient if the empty string gets converted to `nil`.
It makes it easier to work with the input value afterwards,
testing for its presence, using the `||=` operator, and so on.

The complete filter for converting numbers to integers should thus look like this:

``` ruby
  filter: ->{ ( Integer( self, 10 ) rescue self ) unless empty? },
  class: Integer
```

You can even consider using `strip.empty?`
if you want to allow an all-whitespace input to be consumed silently.

Of course, all that would be a lot of typing for something as common as integer parameters.
That's why the `FormInput` class comes with plenty standard filters predefined:

``` ruby
  param :int, INTEGER_ARGS
  param :float, FLOAT_ARGS
  param :bool, BOOL_ARGS       # pulldown style.
  param :check, CHECKBOX_ARGS  # checkbox style.
```

You can check the `form_input/types.rb` source file to see how they are defined
and either use them directly as they are or use them as a starting point for your own variants.

And that's about it.
However, as this chapter is quite important for understanding how the input filters work,
let's reiterate:

   * You can use filters to convert input parameters into any type you want.
   * Make sure the filters keep the original string in case of errors so the user can fix it.
   * You don't have to worry about `nil` input values in filters.
   * Just make sure you treat an empty or blank string as whatever you consider appropriate.

#### Output Format

Now you know how to convert external values into their internal representation,
but that's only half of the story.
The internal values have to be converted to their external representation as well,
and that's what output formatters are for.

By default, the `FormInput` class will use simple `to_s` conversion to create the external value.
But you can easily change this by providing your own `:format` filter instead:

``` ruby
  param :scientific_float, FLOAT_ARGS,
    format: ->{ '%e' % self }
```

The provided block will be called in the context of the parameter value itself
and its result will be passed to the `to_s` conversion to create the final external value.

The use of a formatter is more than just mere cosmetics.
You will often use the formatter to complement your input filter.
For example, this is one possible way of how to map arbitrary external values
to their internal representation and back:

``` ruby
  SORT_MODES = { id: 'n', views: 'v', age: 'a', likes: 'l' }
  SORT_MODE_PARAMETERS = SORT_MODES.invert

  param :sort_mode, :s,
    filter: ->{ SORT_MODE_PARAMETERS[ self ] || self },
    format: ->{ SORT_MODES[ self ] },
    class: Symbol
```

Note that once again the original value is preserved in case of error,
so it can be passed back to the user for fixing.

Another example shows how to process a credit card expiration field:

``` ruby
  EXPIRY_ARGS = {
    placeholder: 'MM/YYYY',
    filter: ->{
      FormInput.parse_time( self, '%m/%y' ) rescue FormInput.parse_time( self, '%m/%Y' ) rescue self
    },
    format: ->{ strftime( '%m/%Y' ) rescue self },
    class: Time,
  }
  param :expiry, EXPIRY_ARGS
```

Note that the formatter won't be called if the parameter value is `nil`
or if it is already a string when it should be some other type
(for example because the input filter conversion failed),
so you don't have to worry about that.
But it doesn't hurt to add the rescue clause like above
just in case the parameter value is set to something unexpected,
especially if the formatter is supposed to be reused at multiple places.

The `FormInput.parse_time` is a helper method which works like `Time.strptime`,
except that it fails if the input string contains trailing garbage.
Without this feature, input like `01/2016` would be parsed as `01/20` by `'%m/%y'`
and interpreted as `01/2020`, which is utterly wrong.
So better use this helper instead if you want your input validated properly.
An added bonus is that it can also ignore the `-_^` modifiers after the `%` sign,
so you can use the same time format string for both parsing and formatting.

To help you get started,
the `FormInput` class comes with several time filters and formatters predefined:

``` ruby
  param :time, TIME_ARGS        # YYYY-MM-DD HH:MM:SS stored as Time.
  param :us_date, US_DATE_ARGS  # MM/DD/YYYY stored as Time.
  param :uk_date, UK_DATE_ARGS  # DD/MM/YYYY stored as Time.
  param :eu_date, EU_DATE_ARGS  # D.M.YYYY stored as Time.
  param :hours, HOURS_ARGS      # HH:MM stored as seconds since midnight.
```

You can use them as they are but feel free to create your own variants instead.

#### Input Transform

So, there are the `:filter` and `:format` options to convert the parameter values
from an external to internal representation and back. So far so good.
But the truth is that the `FormInput` class supports one additional input transformation.
This transformation is set with the `:transform` option
and is invoked after the `:filter` filter.
So, what's the difference between `:filter` and `:transform`?

For scalar values, like normal string or integer parameters, there is none.
In that case the `:transform` is just an additional filter,
and you are free to use either or both.
But `FormInput` class also supports array and hash parameters,
as we will learn in the very next chapter,
and that's where it makes the difference.
The input filter is used to convert each individual element,
whereas the input transformation operates on the entire parameter value,
and can thus process the entire array or hash as a whole.

What you use the input transformation for is up to you.
The `FormInput` class however comes with a predefined `PRUNED_ARGS` transformation
which converts an empty string value to `nil` and prunes `nil` and empty elements from arrays and hashes,
ensuring that the resulting input is free of clutter.
This comes especially handy when used together with array parameters, which we will discuss next.

### Array and Hash Parameters

So far we have been discussing only simple scalar parameters,
like strings or integers.
But web requests commonly support the array and hash parameters as well
using the `array[]=value` and `hash[key]=value` syntax, respectively,
and thus so does the `FormInput` class.

To declare an array parameter, use either the `array` or `array!` method:

``` ruby
  array :keywords, "Keywords"
```

Similarly to `param!`, the `array!` method creates a required array parameter,
which means that the array must be present and may not be empty.
The `array` method on the other hand creates an optional array parameter,
which doesn't have to be filled in at all.
Note that like in case of scalar parameters,
array parameters not found in the input remain set to their default `nil` value,
rather than becoming an empty array.

All the parameter options of scalar parameters can be used with array parameters as well.
In this case, however, they apply to the individual elements of the array.
The array parameters additionally support the `:min_count` and `:max_count` options,
which restrict the number of elements the array can have.
For example, to limit the keywords both in string size and element count, you can do this:

``` ruby
  array :keywords, "Keywords", 35, max_count: 20
```

We have already discussed the input and output filters and input transformation.
The input `:filter` and output `:format` are applied to the elements of the array,
whereas the input `:transform` is applied to the array as a whole.
For example, to get sorted array of integers you can do this:

``` ruby
  array :ids, INTEGER_ARGS, transform: ->{ compact.sort rescue self }
```

The `compact` method above takes care of removing any unfilled entries from the array prior sorting.
This is often desirable,
and if you don't need to use your own transformation,
you can use the predefined `PRUNED_ARGS` transformation which does the same
and discards both `nil` and empty elements:

``` ruby
  array :ids, INTEGER_ARGS, PRUNED_ARGS
  array :keywords, "Keywords", PRUNED_ARGS
```

The hash attributes are very much like the array attributes,
you just use the `hash` or `hash!` method to declare them:

``` ruby
  hash :users, "Users"
```

The biggest difference from arrays is that the hash parameters use keys to address the elements.
By default, `FormInput` accepts only integer keys and automatically converts them to integers.
Their range can be restricted by `:min_key` and `:max_key` options,
which default to 0 and 2<sup>64</sup>-1, respectively.
Alternatively, if you know what are you doing,
you can allow use of non-integer string keys by using the `:match_key` option,
which should specify a regular expression
(or an array of regular expressions)
which all hash keys must match.
This may not be the wisest move, but it's your call.
Just make sure you use the `\A` and `\z` anchors rather than `^` and `$`,
so you don't leave yourself open to nasty surprises.

While practical use of hash parameters with forms is relatively limited,
the array parameters are pretty common.
The examples above could be used for gathering list of input fields into a single array,
which is useful as well,
but the most common use of array parameters is for multi-select or multi-checkbox fields.

To declare a select parameter, you can set the `:type` to `:select` and
use the `:data` option to provide an array of values for the select menu.
The array contains pairs of parameter values to use and the corresponding text to show to the user.
For example, using a [Sequel]-like `Country` model:

``` ruby
  COUNTRIES = Country.all.map{ |c| [ c.code, c.name ] }
  param :country, "Country", type: :select, data: COUNTRIES
```

To turn select into multi-select, basically just change `param` into `array` and that's it:

``` ruby
  array :countries, "Countries", type: :select, data: COUNTRIES
```

Note that it also makes sense to change the parameter name into the plural form, so we did that.

Now if you want to render this as a list of radio buttons or checkboxes instead,
all you need to do is to change the parameter type to `:radio:` or `:checkbox`, respectively:

``` ruby
  param :country, "Country", type: :radio, data: COUNTRIES
  array :countries, "Countries", type: :checkbox, data: COUNTRIES
```

That's all it takes.

To validate the input, you will likely want to make sure the code received is really a valid country code.
In case of scalar parameters, this can be done easily by using the `:check` callback,
which is executed in the context of the parameter itself and can examine the value and do any checks it wants:

``` ruby
  check: ->{ report( "%p is not valid" ) unless Country[ value ] }
```

It can be also done by the `:test` callback,
which is executed in the context of the parameter itself as well,
but receives the value to test as an argument.
In case of arrays and hashes, it is passed each element value in turn,
for as long as no error is reported and the parameter remains valid:

``` ruby
  test: ->( value ){ report( "%p contain invalid code" ) unless Country[ value ] }
```

The advantage of the `:test` callback is that it works the same way regardless of the parameter kind,
scalar or not,
so it is preferable to use it
if you plan to factor this into a `COUNTRY_ARGS` helper which works with both kinds of parameters.

In either case, the `report` method is used to report any problems about the parameter,
which marks the parameter as invalid at the same time.
More on this will follow in the chapter [Errors and Validation](#errors-and-validation).

Alternatively, you may want to convert the country code into the `Country` object internally,
which will take the care of validation as well:

``` ruby
  COUNTRY_ARGS = {
    data: ->{ Country.all.map{ |c| [ c, c.name ] } },
    filter: ->{ Country[ self ] },
    format: ->{ code },
    class: Country
  }
  param! :country, "Country", COUNTRY_ARGS, type: :select
```

Either way is fine, so choose whichever suits you best.
Just note that the data array now contains the `Country` objects themselves rather than their country codes,
and that we have opted for creating that array dynamically instead of using a static one.
And remember that it is really wise to factor reusable things like this
into their own helper like the `COUNTRY_ARGS` above for easier reuse.

Finally, a little bit of warning.
Note that the web request syntax supports arbitrarily nested hash and array attributes.
The `FormInput` class will accept them and apply the input transformations appropriately,
but then it will refuse to validate anything but flat arrays and hashes,
as it is way too easy to shoot yourself in the foot with complex nested structures coming from untrusted source.
The word of advice is just to stay away from those
and let the `FormInput` protect you from such input automatically.
But if you think you know what you are doing and really need such a complex input,
you can use the input transformation
to convert it to flat array or hash,
or intercept the validation and handle the parameter yourself,
which will very likely open a can of worms and leave you prone to many problems.
You have been warned.

### Reusing Form Parameters

It happens fairly often that you will want to use some form parameters at multiple places.
The `FormInput` class provides two ways of dealing with this - form inheritance and parameter copying.

The form inheritance is straightforward.
Simply define some form, then inherit from it and add more parameters as needed:

``` ruby
class NewPasswordForm < PasswordForm
  param! :password_check, "Repeated Password"
end
```

Obviously, the practical use of such approach is very limited.
Most often the parameters you want to reuse won't be the first parameters of the form.
For this reason, the `FormInput` also supports parameter copying which is way more flexible.
You can copy either entire forms or just select parameters like this:

``` ruby
class SignupForm < FormInput
  param! :first_name, "First Name"
  param! :last_name, "Last Name"
  param! :email, "Email"
  copy PasswordForm
end
class ProfileForm < FormInput
  copy SignupForm[ :first_name, :last_name ]
  param :company, "Company"
  param :country, "Country"
end
```

Parameter copying has another advantage - you can actually pass in options
which you want to add or change in the copied versions:

``` ruby
class ChangePasswordForm < FormInput
  param! :old_password, "Old Password"
  copy PasswordForm, title: "New Password"
end
```

Just make sure the new options make sense for all the parameters copied.

### Creating Forms

Now when you know how to create the `FormInput` classes which describe your input parameters,
it's about time you learn how to create the instances of those classes themselves.
We will use the `ContactForm` class from the [Introduction](#form-input) as an example.

First of all, before there is any external input, you will want to create an empty form input instance:

``` ruby
  form = ContactForm.new
```

Once you have it, you can preset its parameters from a hash with the `set` method:

``` ruby
  form.set( email: user.email, name: user.full_name ) if user?
```

If you want to preset the parameters unconditionally,
you may pass the hash directly to the `new` method instead:

``` ruby
  form = ContactForm.new( email: user.email, name: user.full_name )
```

You can even ask your models to prefill complex forms without knowing the details:

``` ruby
  form = ProfileForm.new( user.profile_hash )
```

Later on, after you receive the web request containing the input parameters,
just instantiate the form and fill it with the request input
by passing it the `Rack::Request` compatible `request` argument:

``` ruby
  form = ContactForm.new( request )
```

The `initialize` method internally dispatches any `Hash` argument to the `set` method,
while any other argument is passed to the `import` method,
so the above is equivalent to this:

``` ruby
  form = ContactForm.new.import( request )
```

There is a fundamental difference between the `set` and `import` methods
which you must understand.
The former takes parameters in their internal representation and applies no input processing,
while the latter takes parameters in their external representation and applies input filtering and transformations to them.
It also conveniently ignores any input parameters which the form doesn't define.
On the contrary,  the `set` method can be used to set any attributes of the instance,
even those which are not the form parameters.

Normally, it is pretty safe to simply use the `new` method alone.
You have to make sure to use the `import` method explicitly only
if you have a hash with parameters in their external representation which you want processed.
This can happen for example if you want to use [Sinatra]'s `params` hash
to include parts of the URL as the form input:

``` ruby
  get '/contact/:email' do
    form = ContactForm.new( params )             # NEVER EVER DO THIS!
    form = ContactForm.new.import( params )      # Do this instead if you need to.
  end
```

If you are worried that you might make a mistake,
you can use one of the three helper shortcuts
which make it easier to remember which one to use when:

``` ruby
  form = ContactForm.from_request( request )     # Like new.import, for Rack request with external values.
  form = ContactForm.from_params( params )       # Like new.import, for params hash of external values.
  form = ContactForm.from_hash( some_hash )      # Like new.set, for hash of internal values.
```

Regardless of how you create the form instance,
if you later decide to clear some parameters, you can use the `clear` method.
You can either clear the entire form, named parameters, or parameter subsets (which we will discuss in detail later):

``` ruby
  form.clear
  form.clear( :message )
  form.clear( :name, :company )
  form.clear( form.disabled_params )
```

Alternatively, you can create form copies with just a subset of parameters set:

``` ruby
  form.only( :email, :message )
  form.only( form.required_params )
  form.except( :message )
  form.except( form.hidden_params )
```

Of course, creating copies with either `dup` or `clone` works as well.

In either case, you now have your form with the input parameters set,
and you are all eager to use it.
But before we discuss how to do that,
you need to learn about errors and input validation.

### Errors and Validation

Input validation is a must.
It's impossible to overstate how important it is.
Many applications opt for letting the models do the validation for them,
but that's often way too late.
Besides, lot of input is not intended for models at all.

The `FormInput` class therefore helps you validate all input as soon as possible instead,
before you even touch it.
All you need to do is to call the `valid?` method
and refrain from using the input unless it returns `true`:

``` ruby
  return unless form.valid?
```

Of course, you don't have to give up right away.
The `FormInput` class does all it can so even the invalid input is preserved intact
and can be fed back to the form template so the user can fix it.
The fact that the form says the input is not valid doesn't mean you can't access it.
It's perfectly safe to render the form parameters back in the form template
and it is the intended use.
Just make sure you don't use the invalid input the way you normally would, that's all.

The input validation works by testing the current value of each parameter against
several validation criteria.
As soon as any of these validation restrictions is not met,
an error message describing the problem is reported and remembered for that parameter
and next parameter is tested.
Any parameter with an error message reported is considered invalid
for as long as the error message remains on record.
The entire form is considered invalid as long as any of its parameters are invalid.

It's important to realize that the input validation protection is
only as effective as the individual validation restrictions
you place on your parameters.
When defining your parameters,
always think of how you can restrict them.
It's always better to add too many restrictions than too little
and leave yourself open to exploits caused by unchecked input.

So, what kind of validations are available?
We have already discussed the required vs optional parameters.
The former are required to be present and non-empty.
Empty or `nil` parameter values are allowed only if the parameters are optional.
Unless it is `nil`, the value must also match the parameter kind (string, array or hash).
Note that the `FormInput` provides default error messages for any problems detected,
but you can set a custom error message for required parameters with the `:required_msg` option:

``` ruby
  param! :login, "Login Name",
    required_msg: "Please fill in your Login Name"
```

We have also discussed the string character and byte size limits,
which are controlled by `:min_size`, `:max_size`, `:min_bytesize`, and `:max_bytesize` options, respectively.
The array and hash parameters additionally support the `:min_count` and `:max_count` options,
which limit the number of elements.
The hash parameters also support the `:min_key` and `:max_key` limits to control the range of their integer keys,
plus the `:match_key` pattern(s) to enable restricted use of non-integer string keys.

What we haven't discussed yet are the `:min` and `:max` limits.
When used, these enforce that the input values are
not less than or greater than given limit, respectively.
Similarly, the `:inf` and `:sup` limits (from infimum and supremum)
ensure that the input values are
greater than and less than given limit, respectively.
Note that any of these work with both strings and Numeric types,
as well as anything which responds to the `to_f` method:

``` ruby
  param :age, INTEGER_ARGS, min: 1, max: 200  # 1 <= age <= 200
  param :rate, FLOAT_ARGS, inf: 0, sup: 1     # 0 < rate < 1
```

Additionally, you may specify a regular expression or an array of regular expressions
which the input values must match using the `:match` option.
If you intend to match the input in its entirety,
make sure you use the `\A` and `\z` anchors rather than `^` and `$`,
so a newline in the input doesn't let an unexpected input sneak in:

``` ruby
  param :nick, match: /\A[a-z]+\z/i
```

Custom error message if the match fails can be set with the `:msg` or `:match_msg` options:

``` ruby
  param :password,
    match: [ /[A-Z]/, /[a-z]/, /\d/ ],
    msg: "Password must contain one lowercase and one uppercase letter and one digit"
```

Similarly to `:match`, you may specify a regular expression or an array of regular expressions
which the input values may not match using the `:reject` option.
Custom error message if this fails can be set with the `:msg` or `:reject_msg` options:

``` ruby
  param :password,
    reject: /\P{ASCII}|[\t\r\n]/u,
    reject_msg: "Password may contain only ASCII characters and spaces",
```

Of course, prior to all this, the `FormInput` also ensures
that the strings are in valid encoding and don't contain weird control characters,
so you don't have to worry about that at all.
Alternatively,
for parameters which use a custom object type instead of a string,
the `:class` option ensures that the object is of the correct type instead.

Now, any violation of these restrictions is automatically reported as an error.
Note that `FormInput` normally reports only the first error detected per parameter,
but you can report arbitrary number of custom errors for given parameter
using the `report` method.
This comes handy as it allows you to pass the form into your models
and let them report any belated additional errors which might get detected during the database transaction,
for example:

``` ruby
  form.report( :email, "Email is already taken" ) unless unique_email?( form.email )
```

As we have already seen, it is common to use the `report`
method from within the `:check` or `:test` callback of the parameter itself as well:

``` ruby
  check: ->{ report( "%p is already taken" ) unless unique_email?( value ) }
```

In this case the `%p` string is replaced by the `title` of the parameter.
If the parameter has the `:error_title` option set, it is used preferably instead.
If neither is set, it fallbacks to the parameter `code` name instead.

You can get hash of all errors reported for each parameter from the `errors` method,
or list consisting of first error message for each parameter from the `error_messages` method:

``` ruby
  form.errors          # { email: [ "Email address is already taken" ] }
  form.error_messages  # [ "Email address is already taken" ]
```

You can get all errors or first error for given parameter by using
the `errors_for` or `error_for` method, respectively:

``` ruby
  form.errors_for( :email )  # [ "Email address is already taken" ]
  form.error_for( :email )   # "Email address is already taken"
```

As we have seen, you can test the validity of the entire form with the `valid?` or `invalid?` methods.
You can use those methods for testing validity of given parameter or parameters, too:

``` ruby
  form.valid?
  form.invalid?
  form.valid?( :email )
  form.invalid?( :name, :message )
  form.valid?( form.required_params )
  form.invalid?( form.hidden_params )
```

The validation is run automatically when you first access any of
the validation related methods mentioned above,
so you don't have to worry about its invocation at all.
But you can also invoke it explicitly by calling `validate`, `validate?` or `validate!` methods.
The `validate` method is the standard variant which validates all parameters.
If any errors were reported before already, however, it leaves them intact.
The `validate?` method is a lazy variant which invokes the validation only if it was not invoked yet.
The `validate!` method on the other hand always invokes the validation,
wiping any previously reported errors first.

In either case any errors collected will remain stored
until you change any of the parameter values with `set`, `clear`, or `[]=` methods,
or you explicitly call `validate!`.
Copies created with `dup` (but not `clone`), `only`, and `except` methods
also have any errors reported before cleared.
All this ensures you automatically get consistent validation results anytime you ask for them.
The only exception is when you set the parameter values explicitly using their setter methods.
This intentionally leaves the errors reported intact,
allowing you to adjust the parameter values
without interfering with the validation results.
Which finally brings us to the topic of accessing the parameter values themselves.

### Using Forms

So, now when you have verified that the input is valid,
let's finally use it.

The `FormInput` classes use standard instance variables
for keeping the parameter values,
along with standard read and write accessors.
The simplest way is thus to access the parameters by their name as usual:

``` ruby
  form.email
  form.message ||= "Default text"
```

Note that the standard accessors are defined for you when you declare the parameter,
but you are free to provide your own if you want to.
For example, if you want a parameter to always have some default value instead of the default `nil`,
this is the simplest way to do it:

``` ruby
  param :sort_mode, :s

  def sort_mode
    @sort_mode || 'default'
  end
```

Another way how to access the parameter values is to use the hash-like interface.
Note that it can return an array of multiple attributes at once as well:

``` ruby
  form[ :email ]
  form[ :name ] = user.name
  form[ :first_name, :last_name ]
```

Of course, this interface is often used when you need to access the parameter values programatically,
without knowing their exact name.
The form provides names of all parameters via its `params_names` or `parameters_names` methods,
so you can do things like this:

``` ruby
  form.params_names.each{ |name| puts "#{name}: #{form[ name ].inspect}" }
```

Sometimes, you may want to use some chosen parameters as long as they are all valid,
even if the entire form may be not.
You can do this by using the `valid` method,
which returns the requested values only if they are all valid.
Otherwise it returns `nil`.

``` ruby
  return unless email = form.valid( :email )
  first_name, last_name = form.valid( :first_name, :last_name )
```

To find out if no parameter values are filled at all, you can use the `empty?` method:

``` ruby
  form.set( email: user.email ) if form.empty?
```

The parameters are more than their value, though,
so the `FormInput` allows you to access the parameters themselves as well.
You can get a single named parameter from the `param` or `parameter` methods,
list of named parameters from the `named_params` or `named_parameters` methods,
or all parameters from the `params` or `parameters` methods,
respectively:

``` ruby
  p = form.param( :message )
  p1, p2 = form.named_params( :email, :name )
  list = form.params
```

Once you get hold of the parameter, you can query it about lot of things.
First of all, you can ask it about its `name`, `code`, `title` or `value`:

``` ruby
  p = form.params.first
  puts p.name
  puts p.code
  puts p.title
  puts p.value
```

All parameter options are available via its `opts` hash.
However, it is preferable to query them via the `[]` operator,
which also resolves the dynamic options
and can support localized variants as well:

``` ruby
  puts p[ :help ]       # Use this ...
  puts p.opts[ :help ]  # ... rather than this.
```

The parameter also knows about the form it belongs to,
so you can get back to it using the `form` method if you need to:

``` ruby
  fail unless p.form.valid?
```

As we have seen, you can report errors about the parameter using its `report` method.
You can ask it about all its errors or just the first error using the `errors` or `error` methods, respectively:

``` ruby
  p.report( "This is invalid" )
  p.errors        # [ "This is invalid" ]
  p.error         # "This is invalid"
```

You can also simply ask whether the parameter is valid or not by using the `valid?` and `invalid?` methods.
In fact, the parameter has a dozen of simple boolean getters like this which you can use to ask it about many things:

``` ruby
  p.valid?        # Does the parameter have no errors reported?
  p.invalid?      # Does the parameter have some errors reported?

  p.blank?        # Is the value nil or empty or whitespace only string?
  p.empty?        # Is the value nil or empty?
  p.filled?       # Is the value neither nil nor empty?

  p.required?     # Is the parameter required?
  p.optional?     # Is the parameter not required?

  p.disabled?     # Is the parameter disabled?
  p.enabled?      # Is the parameter not disabled?

  p.hidden?       # Is the parameter type :hidden?
  p.ignored?      # Is the parameter type :ignore?
  p.visible?      # Is the parameter type neither :hidden nor :ignore?

  p.array?        # Was the parameter declared as an array?
  p.hash?         # Was the parameter declared as a hash?
  p.scalar?       # Was the parameter declared as a simple param?

  p.correct?      # Does the value match param/array/hash kind?
  p.incorrect?    # Doesn't the value match the parameter kind?
```

Building upon these boolean getters,
the `FormInput` instance lets you get a list of parameters of certain type.
The following methods are available:

``` ruby
  form.valid_params       # Parameters with no errors reported.
  form.invalid_params     # Parameters with some errors reported.
  form.blank_params       # Parameters with nil, empty, or blank value.
  form.empty_params       # Parameters with nil or empty value.
  form.filled_params      # Parameters with some non-empty value.
  form.required_params    # Parameters which are required and have to be filled.
  form.optional_params    # Parameters which are not required and can be nil or empty.
  form.disabled_params    # Parameters which are disabled and shall be rendered as such.
  form.enabled_params     # Parameters which are not disabled and are rendered normally.
  form.hidden_params      # Parameters to be rendered as hidden in the form.
  form.ignored_params     # Parameters not to be rendered at all in the form.
  form.visible_params     # Parameters rendered normally in the form.
  form.array_params       # Parameters declared as an array parameter.
  form.hash_params        # Parameters declared as a hash parameter.
  form.scalar_params      # Parameters declared as a simple scalar parameter.
  form.correct_params     # Parameters whose current value matches their kind.
  form.incorrect_params   # Parameters whose current value doesn't match their kind.
```

Each of them simply selects the parameters using their boolean getter of the same name.
Each of them is available in the `*_parameters` form for as well,
for those who don't like the `params` shortcut.

As you can see, this allows you to get many parameter subsets,
but sometimes even that is not enough.
For this reason, parameters also support the so-called tagging,
which allows you to group them by any additional criteria you need.
Simply tag a parameter with one or more tags using either the `:tag` or `:tags` option:

``` ruby
  param :age, tag: :indecent
  param :ratio, tags: [ :knob, :limited ]
```

Note that the parameter tags can be also generated dynamically the same way as any other option,
but once accessed, their value is frozen for that parameter instance afterwards,
both for performance reasons and to prevent their inconsistent changes.

You can ask the parameter for an array of its tags with the `tags` method.
Note that it returns an empty array if the parameter was not tagged at all.
Rather than using the tags array directly, though,
it's easier to test parameter's tags using its `tagged?` and `untagged?` methods:

``` ruby
  p.tagged?                                   # Tagged with some tag?
  p.untagged?                                 # Not tagged at all?
  p.tagged?( :indecent )                      # Tagged with this tag?
  p.untagged?( :limited )                     # Not tagged with this tag?
  p.tagged?( :indecent, :limited )            # Tagged with any of these tags?
  p.untagged?( :indecent, :limited )          # Not tagged with any of these tags?
```

You can get the desired parameters using the form's `tagged_params` and `untagged_params` methods, too:

``` ruby
  form.tagged_params                          # Parameters with some tag.
  form.untagged_params                        # Parameters with no tag.
  form.tagged_params( :indecent )             # Parameters tagged with this tag.
  form.untagged_params( :limited )            # Parameters not tagged with this tag.
  form.tagged_params( :indecent, :limited )   # Parameters with either of these tags.
  form.untagged_params( :indecent, :limited ) # Parameters with neither of these tags.
```

What you use this for is up to you.
We will see later that for example the [Multi-Step Forms](#multi-step-forms) use this for grouping parameters which belong to individual steps,
but it has plenty other uses as well.

### URL Helpers

The `FormInput` is primarily intended for use with HTML forms,
which we will discuss in detail in the [Form Templates](#form-templates) chapter,
but it can be used for processing any web request input,
regardless of if it comes from a form post or from the URL query string.
It is therefore quite natural that the `FormInput` provides helpers for generating
URL query strings as well in addition to helpers used for form creation.

You can get a hash of filled parameters suitable for use in the URL query by using the `url_params` method,
or get them combined into the URL query string by using the `url_query` method.
Note that the `url_params` result differs considerably from the result of the `to_hash` method,
as it uses parameter code rather than name for keys and their external representation for the values:

``` ruby
  class MyInput < FormInput
    param :query, :q
    array :feeds, INTEGER_ARGS
  end

  input = MyInput.new( query: "abc", feeds: [ 1, 7 ] )

  input.to_hash       # { query: "abc", feeds: [ 1, 7 ] }
  input.url_params    # { q: "abc", feeds: [ "1", "7" ] }
  input.url_query     # "q=abc&feeds[]=1&feeds[]=7"
```

Unless you want to construct the URL yourself,
you can use the `extend_url` method to let the `FormInput` create the URL for you:

``` ruby
  input.extend_url( "/search" )          # "/search?q=abc&feeds[]=1&feeds[]=7"
  input.extend_url( "/search?e=utf8" )   # "/search?e=utf8&q=abc&feeds[]=1&feeds[]=7"
```

Note that this works well together with the `only` and `except` methods,
which allow you to control which arguments get included:

``` ruby
  input.only( :query ).extend_url( "/search" )    # "/search?q=abc"
  input.except( :query ).extend_url( "/search" )  # "/search?feeds[]=1&feeds[]=7"
```

You can use this for example to create an URL suitable for redirection
which retains only valid parameters when some parameters are not valid:

``` ruby
  # In your class:
  def valid_url( url )
    only( valid_params ).extend_url( url )
  end

  # In your route handler:
  input = MyInput.new( request )
  redirect input.valid_url( request.path ) unless input.valid?
```

If you want to temporarily adjust some parameters just for the creation of a single URL,
you can use the `build_url` method, which combines current parameters with the provided ones:

``` ruby
  input.build_url( "/search", query: "xyz" )  # "/search?q=xyz&feeds[]=1&feeds[]=7"
```

Finally, if you do not like the idea of parameter arrays in your URLs, you can use something like this instead:

``` ruby
  param :feeds,
    filter: ->{ split.map( &:to_i ) },
    format: ->{ join( ' ' ) },
    class: Array

  input.url_params    # { q: "abc", feeds: "1 7" }
  input.url_query     # "q=abc&feeds=1+7"
```

Just note that none of the standard array parameter validations apply in this case,
so make sure to apply your own validations using the `:check` callback if you need to.

### Form Helpers

It may come as a surprise, but `FormInput` provides no helpers for creating HTML tags.
That's because doing so would be a completely futile effort.
No tag helper will suit all your needs when it comes to form creation.

Instead, `FormInput` provides several helpers
which allow you to easily create the forms in the templating engine of your choice.
This has many advantages.
In particular, it allows you to nest the HTML tags exactly the way you want,
style it using whatever classes you want, and include any extra bits the way you want.
Furthermore, it allows you to have templates for rendering the parameters in several styles
and choose among them as you need.
All this and more will be discussed in detail in the [Form Templates](#form-templates) chapter, though.
This chapter just describes the form helpers themselves.

You can ask each form parameter about how it should be rendered by using its `type` method,
which defaults to `:text` if the option `:type` is not set.
Furthermore,
you can ask each form parameter for the appropriate name and value attributes
to use in form elements by using the `form_name` and `form_value` methods.
The simplest form parameters can be thus rendered in [Slim] like this:

``` slim
  input type=p.type name=p.form_name value=p.form_value
```

For array parameters, the `form_value` returns an array of values,
so it is rendered like this:

``` slim
  - for value in p.form_value
    input type=p.type name=p.form_name value=value
```

Finally, for hash parameters, the `form_value` returns an array of keys and values,
and keys are passed to `form_name` to create the actual name:

``` slim
  - for key, value in p.form_value
    input type=p.type name=p.form_name( key ) value=value
```

For parameters which require additional data,
like select, multi-select, or multi-checkbox parameters,
you can ask for the data using the `data` method.
It returns pairs of allowed parameter values together with their names.
If the `:data` option is not set, it returns an empty array.
The values can be passed to the `selected?` method to test if they are currently selected,
and then must be passed to the `format_value` method to turn them into their external representation.
To illustrate all this, a select parameter can be rendered like this:

``` slim
  select name=p.form_name multiple=p.array?
    - for value, name in p.data
      option selected=p.selected?( value ) value=p.format_value( value ) = name
```

Finally, you will likely want to render the parameter name in some way.
For this, each parameter has the `form_title` method,
which returns the title to show in the form.
It defaults to its title, but can be overridden with the `:form_title` option.
If neither is set, the code name will be used instead.
To render it, you will use something like this:

``` slim
  label
    = p.form_title
    input type=p.type name=p.form_name value=p.form_value
```

Of course, you are free to use any other parameter methods as well.
Want to render the parameter disabled?
Add some placeholder text?
It's as simple as adding this to your template:

``` slim
  input ... disabled=p.disabled? placeholder=p[:placeholder]
```

And that's about it.
Check out the [Form Templates](#form-templates) chapter if you want to see more form related tips and tricks.

### Extending Forms

While the `FormInput` comes with a lot of functionality built in,
you will eventually want to extend it further to better fit your project.
To do this, it's common to define the `Form` class inherited from `FormInput`,
put various helpers there, and base your own forms on that.
This is also the place where you can include your own `FormInput` types extensions.
This chapter shows some ideas you may want to built upon to get you started.

Adding custom boolean getters which you may need:

``` ruby
  # Test if the form input which the user can't fix is malformed.
  def malformed?
    invalid?( hidden_params )
  end
```

Adding custom URL helpers, see [URL Helpers](#url-helpers) for details:

``` ruby
  # Add valid parameters to given URL.
  def valid_url( url )
    only( valid_params ).extend_url( url )
  end
```

Keeping track of additional form state:

``` ruby
  # Hook into the request import so we can test form posting.
  def import( request )
    @posted ||= request.respond_to?( :post? ) && request.post?
    super
  end

  # Test if the form content was posted with a post request.
  def posted?
    @posted
  end

  # Explicitly mark the form as posted, to enforce the post action to be taken.
  # Returns self for chaining.
  def posted!
    @posted = true
    self
  end
```

Adding support for your [own types](https://gist.github.com/raxoft/1e717d7dcaab6949ab03):

``` ruby
  MONEY_ARGS = {
    filter: ->{ ( Money( self ) rescue self ) unless empty? },
    format: ->{ Money( self ) },
    class: Money
  }
```

The list could go on and on, as everyone might need slightly different tweaks.
Eventually, though, you will come up with your own set of extensions which you will keep using across projects.
Once you do, consider sharing them with the rest of the world. Thanks.

### Parameter Options

This is a brief but comprehensive summary of all parameter options:

* `:name` - not really a parameter option, this can be used to change the parameter name and code name when copying form parameters.
  See [Reusing Form Parameters](#reusing-form-parameters).
* `:code` - not really a parameter option, this can be used to change the parameter code name when copying form parameters.
  See [Reusing Form Parameters](#reusing-form-parameters).
* `:title` - the title of the parameter, the default value shown in forms and error messages.
* `:form_title` - the title of the parameter to show in forms. Overrides `:title` when present.
* `:error_title` - the title of the parameter to use in error messages containing `%p`. Overrides `:title` when present.
* `:required` - flag set when the parameter is required.
* `:required_msg` - custom error message used when the required parameter is not filled in.
  Default error message is used if not set.
* `:disabled` - flag set when the parameter shall be rendered as disabled.
  Note that it doesn't affect it in any other way, in particular it doesn't prevent it from being set or being invalid.
* `:array` - flag set for array parameters.
* `:hash` - flag set for hash parameters.
* `:type` - type of the form parameter used for form rendering. Defaults to `:text` if not set.
  Other common values are `:password`, `:textarea`, `:select`, `:checkbox`, `:radio`.
  Somewhat special values are `:hidden` and `:ignore`.
* `:data` - array containing data for parameter types which need one, like select, multi-select, or multi-checkbox.
   Shall contain the allowed parameter values paired with the corresponding text to display in forms.
   Defaults to empty array if not set.
* `:tag` or `:tags` - arbitrary symbol or array of symbols used to tag the parameter with arbitrary semantics.
  See the `tagged?` method in the [Using Forms](#using-forms) chapter.
* `:filter` - callback used to cleanup or convert the input values.
  See [Input Filter](#input-filter).
* `:transform` - optional callback used to further convert the input values.
  See [Input Transform](#input-transform).
* `:format` - optional callback used to format the output values.
  See [Output Format](#output-format).
* `:class` - object type (or array thereof) which the input filter is expected to convert the input value into.
  See [Input Filter](#input-filter).
* `:check` - optional callback used to perform arbitrary checks when testing the parameter validity.
  See [Errors and Validation](#errors-and-validation).
* `:test` - optional callback used to perform arbitrary tests when testing validity of each parameter value.
  See [Errors and Validation](#errors-and-validation).
* `:min_key` - minimum allowed value for keys of hash parameters. Defaults to 0.
* `:max_key` - maximum allowed value for keys of hash parameters. Defaults to 2<sup>64</sup>-1.
* `:match_key` - regular expression (or array thereof) which all hash keys must match. Disabled by default.
* `:min_count` - minimum allowed number of elements for array or hash parameters.
* `:max_count` - maximum allowed number of elements for array or hash parameters.
* `:min` - when set, value(s) of that parameter must be greater than or equal to this.
* `:max` - when set, value(s) of that parameter must be less than or equal to this.
* `:inf` - when set, value(s) of that parameter must be greater than this.
* `:sup` - when set, value(s) of that parameter must be less than this.
* `:min_size` - when set, value(s) of that parameter must have at least this many characters.
* `:max_size` - when set, value(s) of that parameter may have at most this many characters.
  Defaults to 255.
* `:min_bytesize` - when set, value(s) of that parameter must have at least this many bytes.
* `:max_bytesize` - when set, value(s) of that parameter may have at most this many bytes.
  Defaults to 255 if `:max_size` is a dynamic option or less than 256.
* `:reject` - regular expression (or array thereof) which the parameter value(s) may not match.
* `:reject_msg` - custom error message used when the `:reject` check fails.
  Defaults to `:msg` message.
* `:match` - regular expression (or array thereof) which the parameter value(s) must match.
* `:match_msg` - custom error message used when the `:match` check fails.
  Defaults to `:msg` message.
* `:msg` - default custom error message used when either of `:match` or `:reject` checks fails.
  Default error message is used if not set.
* `:inflect` - explicit inflection string used for localization.
  Defaults to combination of `:plural` and `:gender` options,
  see [Localization](#localization) for details.
* `:plural` - explicit grammatical number used for localization.
  See [Localization](#localization) for details.
  Defaults to `false` for scalar parameters and to `true` for array and hash parameters.
* `:gender` - grammatical gender used for localization.
  See [Localization](#localization) for details.
* `:row` - used for grouping several parameters together, usually to render them in a single row.
  See [Chunked Parameters](#chunked-parameters).
* `:cols` - optional custom option used to set span of the parameter in a single row.
  See [Chunked Parameters](#chunked-parameters).
* `:group` - custom option used for grouping parameters in arbitrary ways.
  See [Grouped Parameters](#grouped-parameters).
* `:size` - custom option used to set size of `:select` and `:textarea` parameters.
* `:subtitle` - custom option used to render an additional subtitle after the form title.
* `:placeholder` - custom option used for setting the placeholder attribute of the parameter.
* `:help` - custom option used to render a help block explaining the parameter.
* `:text` - custom option used to render an arbitrary text associated with the parameter.

Note that the last few options listed above are not used by the `FormInput` class itself,
but are instead used to pass additional data to snippets used for form rendering.
Feel free to extend this further if you need to pass additional data this way yourself.

## Form Templates

The `FormInput` form rendering is based on the power of standard templates,
the same ones which are used for page rendering.
It builds upon the set of form helpers described in the [Form Helpers](#form-helpers) chapter.
This chapter shows several typical form templates and how they are supposed to be created and used.

First of all, the templates are based on the concept of _snippets_,
which allows the individual template pieces to be reused at will.
Chances are your framework already has support for snippets -
if not, it's usually trivial to build it upon the provided template rendering functionality.
For example, this is a `snippet` helper based on [Sinatra]'s partials:

``` ruby
  # Render partial, our style.
  def snippet( name, opts = {}, locals = nil )
    opts, locals = {}, opts unless locals
    partial( "snippets/#{name}", opts.merge( locals: locals ) )
  end
```

And here is the same thing for [Ramaze]:

``` ruby
  # Render partial, our way.
  def snippet( name, *args )
    render_partial( "snippets/#{name}", *args )
  end
```

Whatever you decide to use, the following examples will simply assume that
the `snippet` method renders the specified template,
while making the optionally provided hash of values accessible as local variables in that template.
We will use [Slim] templates in these examples,
but you could use the same principles in [HAML] or any other templating engine as well.
Also note that you can find the example templates discussed here in the `form_input/example/views` directory.

### Form Template

To put the form on a page, you use the stock HTML `form` tag.
The snippets will be used for rendering of the form content,
but the form itself and the submission buttons used are usually form specific anyway,
so it is rarely worth factoring it out.
Assuming the controller passes the form to the view in the `@form` variable,
simple form using standard [Bootstrap] styling could look like this:

``` slim
form *form_attrs
  fieldset
    == snippet :form_simple, params: @form.params
    button.btn.btn-default type='submit' Submit
```

As you can see, the whole form is just a little bit of scaffolding,
with the bulk rendered by the `form_simple` snippet.
Choosing different snippets allows us to render the form content in different styles easily.
In this case, we are passing in all form parameters as they are,
but note that we could as easily split them or filter them as needed
and render each group differently if necessary.

Note that we are also using the `form_attrs` helper to set the `action` and `method` tag attributes to their default values.
It's a recommended practice to set these explicitly,
so we may as well use a helper which does this consistently everywhere.
For [Sinatra], the helper may look like this:

``` ruby
  # Get hash with default form attributes, optionally overriding them as needed.
  def form_attrs( *args )
    opts = args.last.is_a?( Hash ) ? args.pop : {}
    url = args.shift.to_s unless args.empty?
    fail( ArgumentError, "Invalid arguments #{args.inspect}" ) unless args.empty?
    { action: url || request.path, method: :post }.merge( opts )
  end
```

If you want to use the CSRF protection provided by `Rack::Protection`,
note that you will need to add something like this to the form fieldset:

``` slim
    input type='hidden' name='authenticity_token' value=session[:csrf]
```

To save some typing and to keep things [DRY],
you may turn this into a `form_token` helper and call that instead.
Just make sure the token value is properly HTML escaped.

### Simple Parameters

Now let's have a look at the snippet rendering the form parameters.
It obviously needs to get the list of the parameters to render.
We will pass them in in the `params` variable.
For convenience, we will treat `nil` as an empty list, too.

In addition to that, you will want to control if the errors should be displayed or not.
When the form is displayed for the first time, before the user posts anything,
no errors should be displayed,
but you may want to suppress it explicitly in other cases as well.
We will control this by using the `report` variable.
For convenience, we will provide reasonable default which automatically asks the current request if it was posted or not.

Finally, you will likely want some control over the form autofocus.
For maximum control, we will allow passing in the parameter to focus on in the `focused` variable.
For convenience, though, we will by default autofocus on the first invalid or unfilled parameter,
unless focusing is explicitly disabled by setting `focus` to false.

The snippet prologue which does all this may look like this:

``` slim
- params ||= []
- focus ||= focus.nil?
- report ||= report.nil? && request.post?
- focused ||= params.find{ |x| x.invalid? } || params.find{ |x| x.blank? } || params.first if focus
```

To demonstrate the basics, we will render only the simple scalar parameters.
As for styling, we will choose a simple [Bootstrap] block style,
with the parameter name rendered within the input field itself
using the `placeholder` attribute.
This is something you can often see on compact login pages,
even though it's a practice which is not really [ARIA] friendly.
But as an example it illustrates the possibility to tweak the rendering any way you see fit just fine:

``` slim
- for p in params
  - case p.type
  - when :ignore
  - when :hidden
    input type='hidden' name=p.form_name value=p.form_value
  - else
    .form-group
      input.form-control[
        type=p.type
        name=p.form_name
        value=p.form_value
        placeholder=p.form_title
        disabled=p.disabled?
        autofocus=(p == focused)
      ]
      - if report and error = p.error
        .help-block
          span.text-danger = error
```

As you can see, the snippet uses the `type` attribute to distinguish between the ignored, hidden, and visible parameters.
In further chapters we will see how this can be used to add support for rendering of other parameter types,
like check boxes or pull down menus.
But first we will explore how to properly render array or hash parameters.

### Hidden Parameters

The `FormInput` supports more than scalar parameter types.
As described in the [Array and Hash Parameters](#array-and-hash-parameters) chapter,
the parameters can also contain data stored as arrays or hashes.
This chapter shows how to render such parameters properly.

To focus on the basics, without any complexities getting in the way,
we will use a snippet rendering all parameters as hidden ones as an example.
This is something which is used fairly often,
basically whenever you need to pass some data along within the form without the user seeing them.
The [Rendering Multi-Step Forms](#rendering-multi-step-forms) chapter is a nice example which builds upon this.

The prologue of this snippet is simple, as we need no error reporting nor autofocus handling:

``` slim
- params ||= []
```

The rendering itself is pretty simple as well.
It is free of any styling,
it's just the basic use of parameter's rendering methods as described in the [Form Helpers](#form-helpers) chapter.
You may want to review it after you have seen them used in some context:

``` slim
- for p in params
  - next if p.ignored?
  - next unless p.filled?
  - if p.array?
    - for value in p.form_value
      input type='hidden' name=p.form_name value=value
  - elsif p.hash?
    - for key, value in p.form_value
      input type='hidden' name=p.form_name(key) value=value
  - else
    input type='hidden' name=p.form_name value=p.form_value
```

Having seen the basics, we are now ready to start expanding them towards more complex snippets.

### Complex Parameters

Forms are often more than just few simple text input fields,
so it is necessary to render more complex parameters as well.
To do that,
we will be basically adding code to the `p.type` switch of the following rendering loop:

``` slim
- for p in params
  - next if p.ignored?
  - if p.hidden?
    == snippet :form_hidden, params: [p]
  - else
    .form-group
      - case p.type
      - when ...
      - else
        label
          = p.form_title
          input.form-control[
            type=p.type
            name=p.form_name
            value=p.form_value
            autofocus=(p == focused)
            disabled=p.disabled?
            placeholder=p[:placeholder]
          ]
      - if report and error = p.error
        .help-block
          span.text-danger = error
```

Note how it reuses the snippet we have just described in [Hidden Parameters](#hidden-parameters)
to render all kinds of hidden parameters.
Other than that, however, as it is, the loop renders just normal input fields, like `:text` or `:password`.
So let's extend it right now.

#### Text Area

Text area is basically just a larger text input field with multiline support.

``` slim
- when :textarea
  label
    = p.form_title
    textarea.form-control[
      name=p.form_name
      autofocus=(p == focused)
      disabled=p.disabled?
      rows=p[:size]
    ] = p.form_value
```

Note how we use the `:size` option to control the size of the area.

#### Select and Multi-Select

Select and multi-select allow choosing one or many items from a list of options, respectively.
They are rendered the same way, the only difference is the `multiple` tag attribute.
Thanks to this we can choose between them easily -
we use normal select for scalar parameters and multi-select for array parameters:

``` slim
- when :select
  label
    = p.form_title
    select.form-control[
      name=p.form_name
      multiple=p.array?
      autofocus=(p == focused)
      disabled=p.disabled?
      size=p[:size]
    ]
      - for value, name in p.data
        option selected=p.selected?(value) value=p.format_value(value) = name
```

The data to render comes from the `data` attribute of the parameter,
see the [Array and Hash Parameters](#array-and-hash-parameters) chapter for details.
Also note how the value is passed to the `selected?` method
and how it is formatted by the `format_value` method.

#### Radio Buttons

Radio buttons are for choosing one item from a list of options.
In this regard they are similar to select parameters,
just their appearance in the form is different:

``` slim
- when :radio
  = p.form_title
  - for value, name in p.data
    label
      input.form-control[
        type=p.type
        name=p.form_name
        value=p.format_value(value)
        autofocus=(p == focused)
        disabled=p.disabled?
        checked=p.selected?(value)
      ]
      = name
```

Like in case of select parameters,
the data to render comes from the `data` attribute.
The `selected?` and `format_value` methods are used the same way, too.

#### Checkboxes

Checkboxes can be used in two ways.
You can either use them as individual on/off checkboxes,
or use them as an alternative to multi-select.
Their rendering follows this -
we use the on/off approach for scalar parameters,
and the multi-select one for array parameters:

``` slim
- when :checkbox
  - if p.array?
    = p.form_title
    - for value, name in p.data
      label
        input.form-control[
          type=p.type
          name=p.form_name
          value=p.format_value(value)
          autofocus=(p == focused)
          disabled=p.disabled?
          checked=p.selected?(value)
        ]
        = name
  - else
    label
      - if p.title
        = p.form_title
      input.form-control[
        type=p.type
        name=p.form_name
        value='true'
        autofocus=(p == focused)
        disabled=p.disabled?
        checked=p.value
      ]
      = p[:text]
```

As you can see, the multi-select case is basically identical to rendering of radio buttons,
only the input type attribute changes.
For on/off checkboxes, though, there are more changes.

First of all, you often want no title displayed in front of them,
so we don't show the title if it is not explicitly set.
Of course, this can be applied to rendering of all parameters,
but here it is particularly useful.

Second, you often want some text displayed after them,
like something you are agreeing to, or whatever.
So we use the `:text` option of the parameter to pass this text along.
Note that it is not limited to static text either -
like any other parameter option it can be evaluated at runtime if needed,
see [Defining Parameters](#defining-parameters) for details.
And the [Localization](#localization) chapter will explain how to get the text localized easily.

### Inflatable Parameters

We have seen how to render array parameters as multi-select or multi-checkbox fields.
Sometimes, however, you really want to render them as an array of text input fields.
One way to do this is to render all current values,
plus one extra field for adding new value,
like this:

``` slim
label
  = p.form_title
  - if p.array?
    - values = p.form_value
    - for value in values
      .form-group
        input.form-control[
          type=p.type
          name=p.form_name
          value=value
          autofocus=(p.invalid? and p == focused)
          disabled=p.disabled?
        ]
    - unless limit = p[:max_count] and values.count >= limit
      input.form-control[
        type=p.type
        name=p.form_name
        autofocus=(p.valid? and p == focused)
        disabled=p.disabled?
        placeholder=p[:placeholder]
      ]
  - else
    // standard scalar parameter rendering goes here...
```

Note that if you use something like this,
it makes sense to also add an extra submit button to the form
which will just update the form,
in addition to the standard submit button.
This button will allow the user to add as many items as needed before submitting the form.

### Extending Parameters

The examples above show rendering of parameters which shall take care of most of your needs,
but it doesn't need to end there. Do you need some extra functionality?
It's trivial to pass additional parameter options along and
render them in the template the way you need.
This chapter will show few examples of what can be done.

Do you need to render a subtitle for some parameters?
Just add it after the title like this:

``` slim
  = p.form_title
  - if subtitle = p[:subtitle]
    small =< subtitle
```

Do you want to render an extra help text?
Add it after error reporting like this:

``` slim
  - if report and error = p.error
    .help-block
      span.text-danger = error
  - if help = p[:help]
    .help-block = help
```

Do you want to render all required parameters as such automatically?
Let the snippet add the necessary CSS class like this:

``` slim
  input ... class=(:required if p.required?)
```

Do you want to disable autocomplete for some input fields?
You can do it like this:

``` slim
  input ... autocomplete=(:off if p[:autocomplete] == false)
```

Do you want to add arbitrary tag attributes to the input element, for example some data attributes?
You can put them in a hash and add them using a splat operator like this:

``` slim
  input ... *(p[:tag_attrs] || {})
```

And so on and on.
As you can see, the templates make it really easy to adjust them any way you may need.

### Grouped Parameters

Sometimes you may want to group some parameters together and render the groups accordingly,
say in their own subframe.
It's easy to create a template snippet which does that:

``` slim
- params ||= []
- focus ||= focus.nil?
- report ||= report.nil? && request.post?
- focused ||= params.find{ |x| x.invalid? } || params.find{ |x| x.blank? } || params.first if focus

- for group, params in params.group_by{ |x| x[:group] || x.name }
  h2 = form.group_name( group )
  .form-frame
      == snippet :form_standard, params: params, focus: focus, focused: focused, report: report
```

Note that it uses our standard prologue for focusing and error reporting and then passes those values along,
so the autofocused parameter is selected correctly no matter what group it belongs to.

The example above uses the `group_name` method which is supposed to return the name for given group.
You would have to provide that,
but check out the [Localization Helpers](#localization-helpers) chapter for a tip how it can be done easily.

### Chunked Parameters

Occasionally,
you may want to render some input fields on the same line.
That's when the support for parameter chunking becomes handy.

When declaring the form, add the `:row` option to those parameters.
The value can be anything you want - equal values mean the parameters should be rendered together on the same line.
The `:cols` option can be used if you want specific span of those parameters
in the 12 column grid instead of an evenly distributed split:

``` ruby
  param :nick, "Nick", 32,
    row: 1, cols: 5
  param :email, "Email", EMAIL_ARGS,
    row: 1, cols: 7
```

To enable the chunking itself,
use the `chunked_params` form method instead of the `params` method
to group the parameters appropriately and pass them to the rendering snippet:

``` slim
form *form_attrs
  fieldset
    == snippet :form_chunked, params: @form.chunked_params
    button.btn.btn-default type='submit' Submit
```

The `chunked_params` method leaves all single parameters intact,
but puts all those which belong together into an subarray.

Using for example [Bootstrap] and its standard 12 column grid,
the rendering snippet itself can look like this:

``` slim
- chunked = params || []
- params = chunked.flatten
- focus ||= focus.nil?
- report ||= report.nil? && request.post?
- focused ||= params.find{ |x| x.invalid? } || params.find{ |x| x.blank? } || params.first if focus

- for p in chunked
  - if p.is_a?(Array)
    .row
      - for param in p
        div class="col-sm-#{param[:cols] || 12 / p.count}"
          == snippet :form_standard, params: [param], focus: focus, focused: focused, report: report
  - else
    == snippet :form_standard, params: [p], focus: focus, focused: focused, report: report
```

This example shows a separate snippet which is built on top of another rendering snippets.
But note that the chunking functionality can be incorporated directly into all the other snippets presented so far.
Also note that it works even if you use other means to create the subarrays of parameters to put on the same line.
Again, you are welcome to experiment and tweak the snippets any way you like so they work exactly the way you want them to.

## Multi-Step Forms

You have seen them for sure.
Multi-step forms.
Most shopping sites use them during the checkout.
You confirm the items on one page,
fill delivery information on another,
add payment details on the next
and finally confirm it all on the last one.
Normally, these can be quite a chore to implement,
but `FormInput` makes it all fairly easy.

The following chapters will describe
how to define, use and render such forms in detail.

### Defining Multi-Step Forms

Defining multi-step form is about as simple as defining normal form.
The only difference is that you decide what steps you want,
define them with the `define_steps` method,
then tag each parameter with the step it belongs to using the `:tag` parameter option.

For example, consider the following form:

``` ruby
class PostForm < FormInput
  param! :email, "Email", EMAIL_ARGS

  param :first_name, "First Name"
  param :last_name, "Last Name"

  param :street, "Street"
  param :city, "City"
  param :zip, "ZIP Code"

  param! :message, "Your Message", 1000
  param :comment, "Optional Comment"

  param :url, type: :hidden
end
```

That's a pretty standard form for posting some feedback message, with many fields optional.
It can also track the URL where the user came from in the hidden `:url` field.
Normally, you would display such form on a single page,
but for the sake of the example, we will split it into multiple steps,
having the user fill each block of information on a separate page:

``` ruby
class PostForm < FormInput

  define_steps(
    email: "Email",
    name: "Name",
    address: "Address",
    message: "Message",
    summary: "Summary",
    post: nil,
  )

  param! :email, "Email", EMAIL_ARGS, tag: :email

  param :first_name, "First Name", tag: :name
  param :last_name, "Last Name", tag: :name

  param :street, "Street", tag: :address
  param :city, "City", tag: :address
  param :zip, "ZIP Code", tag: :address

  param! :message, "Your Message", tag: :message
  param :comment, "Optional Comment", tag: :message

  param :url, type: :hidden
end
```

The `define_steps` method takes a hash of symbols which define the steps
along with their names which can be displayed to the user.
It also extends the form with step-related functionality,
which will be described in detail in the [Multi-Step Form Functionality](#multi-step-form-functionality) chapter.
The steps are defined in the order which will be used to progress through the form -
the user starts at the first step and finishes at the last
(at least that's the most typical flow).

The `:tag` option is then used to assign each parameter to particular step.
If you would need additional tags, remember that you can use the `:tags` array instead as well.
Also note that the hidden parameter doesn't have to belong to any step,
as it will be always rendered as a hidden field anyway.

As you can see, we have split the parameters among four steps.
But we have defined more steps than that -
there can be steps which have no parameters assigned to them.
Such extra steps are still used for tracking progress through the form.
In this example, the `:summary` step is used to display the form data
gathered so far and giving the user the option of re-editing them before posting them.
Similarly, you could have an initial `:intro` step or some other intermediate steps if you wanted.
The final `:post` step serves as a terminator which we will use to actually process the form data.
Note that it doesn't have a name,
so it won't appear among the list of step names if we decide to display them somewhere
(see [Rendering Multi-Step Forms](#rendering-multi-step-forms) for example of that).

We will soon delve into how to use such forms, but first let's discuss their enhanced functionality.

### Multi-Step Form Functionality

Using `define_steps` in a form definition extends the range of the methods available,
in addition to those described in the [Form Helpers](#form-helpers) chapter.
It also adds several internal form parameters which are crucial for keeping track of the progress through the form.

The most important of those parameters is the `step` parameter.
It is always set to the name of the current step,
starting with the first step defined by default.
If you need to, you can change the current step by simply assigning to it,
we will see examples of that later in the [Using Multi-Step Forms](#using-multi-step-forms) chapter.

The second important parameter is the `next` parameter.
It contains the desired step which the user wants to go to whenever he posts the form.
This parameter is used to let the user progress throughout the form -
we will see examples of that in the [Rendering Multi-Step Forms](#rendering-multi-step-forms) chapter.
If it is set and there are no problems with the parameters of the currently submitted step,
it will be used to update the value of the `step` parameter,
effectively changing the current step to whatever the user wanted.
Otherwise the `step` value is not changed and the current step is retained.

There are two more parameters which are internally used for keeping information about previously visited steps.
The `last` parameter contains the highest step among the steps seen by the user, including the current step.
The `seen` parameter contains the highest step among the steps seen by the user before the current step was displayed.
Unlike the `last` parameter, which is always set, the `seen` parameter can be `nil` if no steps were displayed before yet.
The current step is not included when it is displayed for the first time,
it will become included only if it is displayed more than once.
Neither of these parameters is usually used directly, though.
Instead, they are used by several helper methods for classifying the already visited steps,
which we will see shortly.

There are three methods added which extend the list of methods
which can be used for getting lists of form parameters.
The `current_params` method provides the list of all parameters which belong to the current step,
while the `other_params` method provides the list of those which do not.
Then there is the `step_params` method which returns the list of all parameters for given step.

``` ruby
  form = PostForm.new
  form.current_params.map( &:name )        # [:email]
  form.other_params.map( &:name )          # [:first_name, :last_name, ..., :comment, :url]
  form.step_params( :name ).map( &:name )  # [:first_name, :last_name]
```

The rest of the methods added is related to the steps themselves.
The `steps` method returns the list of symbols defining the individual steps.
The `step_names` method returns the hash of steps which have a name along with their names.
The `step_name` method returns the name of current/given step, or `nil` if it has no name defined.
The `next_step_name` and `previous_step_name` are handy shortcuts for getting
the name of the next and previous step, respectively.

``` ruby
  form.steps                  # [:email, :name, :address, :message, :summary, :post]
  form.step_names             # {email: "Email", name: "Name", ..., message: "Message", summary: "Summary"}
  form.step_name              # "Email"
  form.step_name( :address )  # "Address"
  form.step_name( :post )     # nil
  form.next_step_name         # "Address"
  form.previous_step_name     # nil
```

Then there are methods dealing with the step order.
The `step_index` method returns the index of the current/given step.
The `step_before?` and `step_after?` methods test
if the current step is before or after given step, respectively.
The `first_step` method returns the first step defined,
and the `last_step` method returns the last step defined.
If provided with a list of step names,
these methods return the first/last valid step among them, respectively.
The `next_step` method returns the step following the current/given step,
or `nil` if there is no next step,
and
the `previous_step` method returns the step preceding the current/given step,
or `nil` if there is no previous step.
Finally,
the `next_steps` method returns the list of steps following the current/given step,
and the `previous_steps` method returns the list of steps preceding the current/given step.

``` ruby
  form.step_index                     # 0
  form.step_index( :address )         # 2
  form.step_before?( :summary )       # true
  form.step_after?( :email )          # false
  form.first_step                     # :email
  form.first_step( :message, :name )  # :name
  form.last_step                      # :post
  form.last_step( :message, :name )   # :message
  form.next_step                      # :name
  form.next_step( :message )          # :summary
  form.next_step( :post )             # nil
  form.previous_step                  # nil
  form.previous_step( :message )      # :address
  form.previous_step( :email )        # nil
  form.next_steps                     # [:name, :address, :message, :summary, :post]
  form.next_steps( :address )         # [:message, :summary, :post]
  form.previous_steps                 # []
  form.previous_steps( :address )     # [:email, :name]
```

Then there is a group of boolean getter methods which
can be used to query the current/given step about various things:

``` ruby
  form.first_step?                # Is this the first step?
  form.last_step?                 # Is this the last step?
  form.regular_step?              # Does this step have some parameters assigned?
  form.extra_step?                # Does this step have no parameters assigned?
  form.required_step?             # Does this step have some required parameters?
  form.optional_step?             # Does this step have no required parameters?
  form.filled_step?               # Were some of the step parameters filled already?
  form.unfilled_step?             # Were none of the step parameters filled yet?
  form.correct_step?              # Are all of the step parameters valid?
  form.incorrect_step?            # Are some of the step parameters invalid?
  form.enabled_step?              # Are not all of the step parameters disabled?
  form.disabled_step?             # Are all of the step parameters disabled?

  form.first_step?( :email )      # true
  form.last_step?( :post )        # true
  form.regular_step?( :name )     # true
  form.extra_step?( :post )       # true
  form.required_step?( :message ) # true
  form.optional_step?( :post )    # true
  form.filled_step?( :post )      # true
  form.unfilled_step?( :name )    # true
  form.correct_step?( :post )     # true
  form.incorrect_step?( :email )  # true
  form.enabled_step?( :name )     # true
  form.disabled_step?( :post )    # false
```

Note that the extra steps, which have no parameters assigned to them,
are always considered optional, filled, correct and enabled
for the purpose of these methods.

Based on these getters,
there is a group of methods which return a list of matching steps.
In this case, however, the extra steps are excluded for convenience
from all these methods (except the `extra_steps` method itself, of course):

``` ruby
  form.regular_steps      # [:email, :name, :address, :message]
  form.extra_steps        # [:summary, :post]
  form.required_steps     # [:email, :message]
  form.optional_steps     # [:name, :address]
  form.filled_steps       # []
  form.unfilled_steps     # [:email, :name, :address, :message]
  form.correct_steps      # [:name, :address]
  form.incorrect_steps    # [:email, :message]
  form.enabled_steps      # [:email, :name, :address, :message]
  form.disabled_steps     # []
```

The first of the incorrect steps is of particular interest,
so there is a shortcut method `incorrect_step` just for that:

``` ruby
  form.incorrect_step     # :email
```

Finally, there is a group of methods which deal with the progress through the form.
Normally, the user starts at the first step,
and proceeds to the next step whenever he submits valid parameters for the current step.
If the submitted parameters contain some errors,
the current step is not advanced and the errors are reported,
allowing the user to fix them before moving on.
Eventually the user reaches the last step,
at which point the form is finally processed.
That's the standard flow, but it can be changed by allowing the user
to go back and forth to all the steps he had visited previously.

There are several methods for getting a list of steps in the corresponding range.
The `finished_steps` method returns the list of steps
which the user has visited and submitted before.
The `unfinished steps` method returns the list of steps
which the user has not visited yet, or visited for the first time.
The `accessible_steps` method returns the list of steps
which the user has visited already.
The `inaccessible_steps` method returns the list of steps
which the user has not visited yet at all.
There is also the matching set of boolean getter methods
which can be used to query the same information about individual steps.

``` ruby
  form.finished_steps               # []
  form.unfinished_steps             # [:email, :name, :address, :message, :summary, :post]
  form.accessible_steps             # [:email]
  form.inaccessible_steps           # [:name, :address, :message, :summary, :post]

  form.finished_step?               # false
  form.unfinished_step?             # true
  form.accessible_step?             # true
  form.inaccessible_step?           # false

  form.finished_step?( :email )     # false
  form.unfinished_step?( :post )    # true
  form.accessible_step?( :email )   # true
  form.inaccessible_step?( :post )  # true
```

By default, only the first step is initially accessible,
but you can change that by using the `unlock_steps` method,
which makes all steps instantly accessible.
This can be handy for example when the whole form is prefilled with some previously acquired data,
so the user can access any step from the very beginning:

``` ruby
  form = PostForm.new( user.latest_post.to_hash ).unlock_steps
```

If you decide to display the individual steps in the masthead or the sidebar,
it is often desirable to mark them not only as accessible or inaccessible,
but also as correct or incorrect.
This last group of methods is intended for that.
The `complete_step?` method can be used to test
if the current/given step was finished and contains no errors.
The `incomplete_step?` method can be used to test
if the current/given step was finished but contains errors.
The `good_step?` method tests if the current/given step should be visualized as good
(green color, check sign, etc.).
By default it returns `true` for finished, correctly filled regular steps,
but your form can override it to provide different semantics.
The `bad_step?` method tests if the current/given step should be visualized as bad
(red color, cross or exclamation mark, etc.).
By default it returns `true` for finished but incorrect steps,
but again you can override it if you wish.
As usual, there are the corresponding methods
which can be used to get lists of all the matching steps at once:

``` ruby
  form = PostForm.new.unlock_steps
  form.complete_steps               # [:name, :address, :summary, :post]
  form.incomplete_steps             # [:email, :message]
  form.good_steps                   # []
  form.bad_steps                    # [:email, :message]

  form.complete_step?               # false
  form.incomplete_step?             # true
  form.good_step?                   # false
  form.bad_step?                    # true

  form.complete_step?( :name )      # true
  form.incomplete_step?( :email )   # true
  form.good_step?( :name )          # false
  form.bad_step?( :email )          # true
```

And that's it.
Now let's have a look at some practical use of these helpers.

### Using Multi-Step Forms

Using the multi-step forms is not much different from the normal forms.
Creating the form initially is the same, as is presetting the parameters:

``` ruby
  get '/post' do
    @form = PostForm.new( email: user.email )
    slim :post_form
  end
```

Processing the submitted form is nearly the same, too.
The only difference is that you keep doing nothing until the user reaches the last step.
Then you validate the form, and if there are some problems,
return the user to the appropriate step to fix them.
Normally, the user shouldn't be able to proceed to the last step if there are errors,
but people can always try to trick the form by submitting any parameters they want,
so you should be ready for that.
Returning them to the incorrect step is more polite than just failing with an error,
but you could do that as well if you wanted.
In either case,
once the user gets to the last step and there are no errors,
you use the form the same way you would use any regular form.

``` ruby
  post '/post' do
    @form = PostForm.new( request )

    # Wait for the last step.
    return slim :post_form unless @form.last_step?

    # Make sure the form is really valid.
    unless @form.valid?
      @form.step = @form.incorrect_step
      return slim :post_form
    end

    # Now somehow use the submitted data.
    user.create_post( @form )
    slim :post_created
  end
```

And that's it.
I told you it was easy.
Of course, you can utilize more of the helpers described in
the [Multi-Step Form Functionality](#multi-step-form-functionality) chapter
and do more complex things if you wish,
but the example above is the basic boilerplate you will likely want to start with most of the time.

### Rendering Multi-Step Forms

Rendering the multi-step form is similar to rendering of regular forms as well.
The biggest difference is that you render the parameters for the current step normally,
while all other parameters are rendered as hidden input elements.
The most basic multi-step form could thus look like this:

``` slim
form *form_attrs
  fieldset
    == snippet :form_standard, params: @form.current_params, report: @form.finished_step?
    == snippet :form_hidden, params: @form.other_params
    button.btn.btn-default type='submit' name='next' value=@form.next_step Proceed
```

See how the submit button uses the `next` value to proceed to the next step.
Without it, the form would be merely updated when submitted.

Also note how we control when to display the errors -
we use the `finished_step?` method to suppress the errors whenever
the user sees certain step for the first time.

Note that it is also possible to divert the form rendering for individual steps if you need to.
If we follow the `PostForm` example,
you will want to render the `:summary` step accordingly, for example like this:

``` slim
    h2 = @form.step_name
    - if @form.step == :summary
      == snippet :form_hidden, params: @form.params
      dl.dl-horizontal
        - for p in @form.visible_params
          dt = p.title
          dd = p.value
    - else
      == snippet :form_standard, params: @form.current_params, report: @form.finished_step?
      == snippet :form_hidden, params: @form.other_params
```

Of course, you will likely want your form to use more fancy submit buttons as well.
For example, you can use more specific submit buttons for each step instead:

``` slim
    .btn-toolbar.pull-right
      - if name = @form.next_step_name
        button.btn.btn-default type='submit' name='next' value=@form.next_step Next Step: #{name}
      - else
        button.btn.btn-primary type='submit' name='next' value=@form.next_step Send Post
```

If you want to provide button for updating the form content without proceeding to the next step,
simply include something like this:

``` slim
      -unless @form.extra_step?
        button.btn.btn-default type='submit' Update
```

To allow users to go back to the previous step, prepend something like this:

``` slim
    - if name = @form.previous_step_name
      .btn-toolbar.pull-left
        button.btn.btn-default type='submit' name='next' value=@form.previous_step Previous Step: #{name}
```

Note that browsers nowadays automatically use the first submit button when the user hits the enter in the text field.
If you have multiple buttons in the form and the first one is not guaranteed to be the one you want,
you can add the following invisible button as the first button in the form to make the browser go to the step you want:

``` slim
  button.invisible type='submit' name='next' value=@form.next_step tabindex='-1'
```

When rendering the multi-step form,
it also makes sense to display the individual steps in some way
so the user can see what steps there are and to see his progress.
Common ways are a form specific masthead above the form or a sidebar next to the form.
The basic masthead can be rendered like this:

``` slim
  ul.form-masthead
    - for step, name in @form.step_names
      li[
        class=(:active if step == @form.step)
        class=(:disabled unless @form.accessible_step?( step ))
      ]
        = name
```

This uses the typical CSS classes to distinguish between the current, accessible and inaccessible steps.
If you also want to somehow mark the correct and incorrect steps,
you can append something like this:

``` slim
        - if @form.bad_step?( step )
          span.pull-right.glyphicon.glyphicon-exclamation-sign.text-danger
        - elsif @form.good_step?( step )
          span.pull-right.glyphicon.glyphicon-ok-sign.text-success
```

Users also often expect to be able to click the individual steps to go directly to that step.
To allow that, simply change the list elements to buttons which can be clicked like this:

``` slim
  ul.form-masthead
    - for step, name in @form.step_names
      - if @form.accessible_step?( step )
        li class=(:active if step == @form.step)
          button type='submit' name='next' value=step tabindex='-1'
            = name
      - else
        li.disabled = name
```

Note that in this case you will almost certainly want to include the invisible button
we have mentioned above as the first button in the form
to make sure hitting the enter in the text field works as expected.

Of course, once again it is trivial to extend these examples with anything you need.
Do you want to show tips about each form step as the user hovers over them?
Simply add the `step_hint` method to your form to return the text to display
and add the hint with the title attribute like this:

``` slim
        li ... title=@form.step_hint( step )
```

The list of the possible enhancements could go on and on.
As your multi-step form navigation gets more complex,
you will likely want to factor it out to its own snippet.
This will allow you to share it among multiple forms
and even switch visual styles with ease.

## Localization

Working with forms in one way or another implies showing lot of text to the user.
Chances are that sooner or later you'll want that text to become localized.
The good news is that the `FormInput` comes with full featured localization support already built in.
These chapters explain in detail how to take advantage of all its features.

The `FormInput` localization is built on [R18n].
R18n is a neat tiny gem for all your localization needs.
It is a no-nonsense, right-to-the-point toolkit developed by people who understand the subject.
It even comes with an [I18n] compatible drop-in replacement for [Rails],
so you can switch to it with ease.
If you are serious about localization,
you should definitely check it out.

If your project already uses R18n,
requiring `form_input` will detect it and make the localization support available automatically.
Otherwise you can make it available explicitly by requiring `form_input/r18n` in your application:

``` ruby
  require `form_input/r18n`
```

Then all you need to do is to set the desired R18n locale:

``` ruby
  R18n.set('en')     # For generic English.
  R18n.set('en-us')  # For American English.
  R18n.set('en-gb')  # For British English.
  R18n.set('cs')     # For Czech.
```

Note that how exactly is this done can differ slightly depending on the framework you use.
For example, if you use [Sinatra] together with the [sinatra-r18n] gem,
the locale is set automatically for you for each request by the R18n helper.
Likewise if you use [Rails] together with the [r18n-rails] gem.
Please refer to the [R18n] documentation for more details.

Anyway, once the localization is enabled, the following features become available:

* All builtin error messages and other builtin strings become localized.
* Full inflection support is enabled for all builtin error messages.
* All string parameter options can be localized.
* All multi-step form step names can be localized.
* The R18n `t` and `l` helpers become available in both form and parameter contexts.
* Additional `ft` helper becomes available in both form and parameter contexts.
* Additional `pt` helper becomes available in the parameter context.

Note that the full inflection support alone can be useful on its own,
so you may want to explore the following chapters
even if you don't plan to translate the application to other languages yet.

### Error Messages and Inflection

Validation and error reporting are major `FormInput` features.
Normally, `FormInput` uses builtin English error messages.
It pluralizes the names of the units it displays properly,
but provides little inflection support beyond that.
It assumes that all scalar parameter names use singular case
and all array and hash parameter names use plural case.
This is most often the case, but not always.
If you need something more flexible, you may need to enable the localization support.

With localization enabled,
the list of builtin error messages becomes replaced by
string translations managed by [R18n] in the `form_input` namespace.
You can find the available translation files in the `form_input/r18n` directory.
The same path can be obtained at runtime from the `FormInput.translations_path` method.
The translations of the error messages were created with inflection in mind
and the message variants are chosen according to the inflection rules of the parameter names automatically -
the [Inflection Filter](#inflection-filter) chapter will explain the gory details.

For English, the inflection rules are pretty simple.
You only need to distinguish between singular and plural grammatical number.
By default,
`FormInput` uses singular for scalar parameters and plural for array and hash parameters.
With localization enabled,
you can override it by setting the `:plural` parameter option to `true` or `'p'` for plural,
and to `false` or `'s'` for singular, respectively:

``` ruby
  param :keywords, "Keywords", plural: true
  array :countries, "List of countries", plural: false
```

The boolean values make sense for most languages,
but note that there are languages which have more than two grammatical numbers,
and that's when the string values may become useful.
Regardless of which way you use,
the `plural` method can be used to get the string matching
the grammatical number of given parameter for the currently active locale.

However, grammatical number is not the only thing to take care of.
For many languages, the rules are more complex than that.
You usually need to take the grammatical gender into account as well.
Instead of using single set of error messages and forcing you to use single grammatical gender to fit them all,
`FormInput` allows you to use the `:gender` option to specify the grammatical gender of each parameter explicitly.
Its value is one of the shortcuts of the grammatical genders used by the translation file for given language -
check the corresponding file in the `form_input/r18n` directory for specific details.
The following gender values are typically available:

* `n` - neuter
* `f` - feminine
* `m` - masculine
* `mi` - inanimate masculine
* `ma` - animate masculine
* `mp` - personal masculine

When not set, the default value is `n` for neuter gender,
which is suitable for example for English,
but other languages can set the default to be something else,
typically `mi` for inanimate masculine gender.
See the `default_gender` value in
the corresponding file in the `form_input/r18n` directory.
In either case,
the `gender` method can be used to get the string containing
the grammatical gender of given parameter for the currently active locale.

To see how this works in real life, here are several parameters with properly inflected Czech titles:

``` ruby
  param :email, "Email"
  param :name, "Jméno", gender: "n"
  param :address, "Adresa", gender: "f"
  param :keywords, "Klíčová slova", plural: true, gender: "n"
  param :authors, "Autoři", plural: true, gender: "ma"
```

However, even if it is possible to use non-English names directly in the forms like this,
assuming you also set the R18n locale to the corresponding value,
it is not very common.
The whole point of localization is usually to extract the texts to external files,
so they can be translated and localized to different languages.
The next chapter will explain how to do that.

### Localizing Forms

If you have started creating your `FormInput` forms without thinking about localization,
the good news are that the forms will not require much changes to become localized.
In fact, most of your form strings will be taken care of automatically.
Only strings which you might have used within the dynamically evaluated parameter options
or parameter callbacks
will need to be localized explicitly with the help of the [Localization Helpers](#localization-helpers).

To localize your project,
you will first need to add the R18n translation files to it.
See the [R18n] documentation for details on how is this done
and where the files are supposed to be placed.
Once you have the R18n directory structure set up, you just need to localize the forms themselves.
To get you started, `FormInput` provides a localization helper to create the default translation file for you.
All you need to do is to run `irb`, require all of your project files,
then run the following:

``` ruby
  require 'form_input/localize'
  File.write( 'en.yml', FormInput.default_translation )
```

This creates a [YAML] file called `en.yml` which contains
the default translations for all your forms in the format directly usable by R18n.
Of course, if for some reason your default project language is not English,
adjust the name of the file accordingly.

For example, for a project containing only the `ContactForm` from the [Introduction](#form-input) section
the content of the default translation file would look like this:

``` yaml
---
forms:
  contact_form:
    email:
      title: Email address
    name:
      title: Name
    company:
      title: Company
    message:
      title: Message
```

As you can see,
all form related strings reside within the `forms` namespace,
so it shall not interfere with your other translations.
You can merge it with your main `en.yml` in the `/i18n/` directory,
or, if you want to keep it separate,
you can put it in its own subdirectory, say `/i18n/forms/en.yml`.

Once you have the `en.yml` file in place,
R18n shall pick it up automatically.
To make sure it is all working,
temporarily change some of the form titles in the translation file to something else
and it shall change on the rendered page accordingly.
If it doesn't seem to work, try adding something like the following bit somewhere on some page
and make it work first
(of course, adjust the name of the form and parameter accordingly to match your real project):

``` slim
  pre = t.forms.contact_form.email.title
```

Please refer to the [R18n] documentation for more troubleshooting help if you still need assistance.

Once you get the default translation file working,
you are all set to start adding other translation files
for all the languages you want.
But first you should understand the content of those files and how to use it.
The next chapters will explain it in detail.

### Localizing Parameters

Each form derived from `FormInput` has its own namespace in the global `forms` [R18n] namespace.
The name of this namespace is returned by the `translation_name` method of each form class.
It's basically the snake_case conversion of the CamelCase name of the form class.

Each of the form parameters has its own namespace within the namespace of the form to which it belongs.
The name of this namespace is the same as the `name` attribute of the parameter.
Each of the parameter options can be localized by simply adding
the appropriate translation within this parameter namespace.
Remember that the `title` attribute of the parameter is nothing more than just one of the possible [Parameter Options](#parameter-options),
so it applies to it as well.

The localization of the `ContactForm`
from the [Introduction](#form-input) section
thus looks like this:

``` yaml
forms:
  contact_form:
    email:
      title: Email address
    name:
      title: Name
    company:
      title: Company
    message:
      title: Message
```

To translate it say from English to Czech,
copy it from the `en.yml` file to the `cs.yml` file
and then adjust it for example like this:

``` yaml
forms:
  contact_form:
    email:
      title: Email
    name:
      title: Jméno
      gender: n
    company:
      title: Společnost
      gender: f
    message:
      title: Zpráva
      gender: f
```

Note the use of the `:gender` option to get properly inflected error messages.

Now let's say we decide to use a custom error message when the user forgets to fill in the content of the message field.
To do this, we add the value of the `:required_msg` option of the `message` parameter directly to the `en.yml` file like this:

``` yaml
    message:
      title: Message
      required_msg: Message with no content makes no sense.
```

Note that this works even if you don't add the `:required_msg` option to the parameter
within the `ContactForm` class definition itself.
That's because as long as you have the locale support enabled,
all applicable parameter options are automatically looked up in the translation files first.
If the corresponding translation is found,
it is used regardless of the parameter option value declared in the form.
This allows you to completely remove the texts from the form definitions themselves
and to keep them all in one place,
which makes the localization easier to maintain in the long term.

The texts present in the class definition are used only as a fallback if no corresponding translation is found at all.
This is particularly handy when you are adding new parameters which you haven't added into any of the translation files yet.
However note that R18n normally provides its own default translation based on its builtin fallback sequence for each locale,
usually falling back to English in the end.
This means that once you add some translation to the `en.yml` file,
the parameter option will get this English translation for all other locales as well,
until you add the corresponding translation to the other translations files as well.

So, to make sure we get the Czech version of the `:required_msg` for the example above,
the `cs.yml` file should be updated as well like this:

``` yaml
    message:
      title: Zpráva
      gender: f
      required_msg: Zpráva bez obsahu nemá žádný smysl.
```

And that's about it.
This alone will allow you to localize and translate most if not all of your forms completely.
However,
if you were using some texts within the dynamically evaluated options or parameter callbacks
like `:check` or `:test`,
you will need to replace them with the use of the localization helpers which we will describe in next chapter.

### Localization Helpers

The R18n provides two main shortcut methods, `t` and `l`,
which are used for translating texts and localizing objects, respectively.
See the [R18n] documentation for details.
When the localization support is enabled,
the `FormInput` makes these two methods available in both parameter and form contexts.
It also adds two additional helper methods similar to the `t` method, called `ft` and `pt`.
Either of these methods can be used to translate texts other than those automatically handled by the `FormInput` itself.

The `ft` method is usable in both parameter and form contexts.
It works like the `t` method,
except that all translations are automatically looked up in the form's own `forms.<form_translation_name>` namespace,
rather than the global namespace.
Note that it supports the `.`, `()`, and `[]` syntax alternatives for getting the desired translation.
The latter two forms are handy when the text name is obtained programatically.

``` ruby
  form = ContactForm.new
  form.ft.some_text           # Returns forms.contact_form.some_text translation.
  form.ft( :some_text )       # Ditto.
  form.ft[ :some_text ]       # Ditto.
```

Note that it is possible to pass arguments to the translation as usual:

``` ruby
  form.ft.other_text( 1 )     # Returns forms.contact_form.other_text translation, using 1 as an argument.
  form.ft( :other_text, 1 )   # Ditto.
  form.ft[ :other_text, 1 ]   # Ditto.
```

Of course, nesting of translations is possible as usual as well:

``` ruby
  form.ft.errors.generic      # Returns forms.contact_form.errors.generic translation.
  form.ft( :errors ).generic  # Ditto.
  form.ft[ :errors ].generic  # Ditto.
```

The `ft` method is typically used in methods which encapsulate the lookup of translated text within your form.
For example, here is how the `group_name` method
mentioned in the [Grouped Parameters](#grouped-parameters) chapter
might look like:

``` ruby
  def group_name( group )
    ft.groups[ group ]
  end
```

The `pt` method is usable only in the parameter context.
It works similar to the `ft` method,
except that all translations are automatically looked up in the parameter's own ``forms.<form_translation_name>.<parameter_name>` namespace,
rather than the global namespace.

``` ruby
  p = form.params.first
  p.pt.some_text             # Returns forms.contact_form.email.some_text translation.
  p.pt( :some_text )         # Ditto.
  p.pt[ :some_text ]         # Ditto.
  p.pt.other_text( 1 )       # Returns forms.contact_form.email.other_text translation,
  p.pt( :other_text, 1 )     # Ditto.                                    using 1 as an argument.
  p.pt[ :other_text, 1 ]     # Ditto.
  p.pt.errors.generic        # Returns forms.contact_form.email.errors.generic translation.
  p.pt( :errors ).generic    # Ditto.
  p.pt[ :errors ].generic    # Ditto.
```

Like the `ft` method, it provides three syntax alternatives for getting the desired translation.
It's worth mentioning that the `()` syntax automatically appends the parameter itself as the last argument,
making it available for the [Inflection Filter](#inflection-filter), which will be discussed later.

The `pt` method is typically used in parameter callbacks and
in dynamically evaluated parameter options.
For example, the text in the following callback

``` ruby
    check: ->{ report( "This password is not secure enough" ) unless form.secure_password?( value ) }
```

can be replaced with properly translated parameter specific variant like this:

``` ruby
    check: ->{ report( pt.insecure_password ) unless form.secure_password?( value ) }
```

It is also handy when the text requires some parameters:

``` ruby
  param! :password, "Password", PASSWORD_ARGS,
    help: ->{ pt.help( self[ :min_size ], self[ :max_size ] ) }
```

Note that the texts translated like this are usually parameter specific
so they can be inflected and adjusted as needed by the translator directly.
However, if you are preparing something which is intended to be reused,
you will likely want to have the messages automatically inflected according to the parameter used.
This is when the [Inflection Filter](#inflection-filter) comes to help.
All you need to do is to pass the form parameter as the last argument to the translation getter like this:

``` ruby
  EVEN_ARGS = {
    test: ->( value ){ report( t.forms.errors.odd_value( self ) ) unless value.to_i.even? }
  }
```

You can even do something more fancy,
for example distinguish between the scalar and array and hash parameters,
or pass in the rejected value itself as an additional parameter,
like this:

``` ruby
  EVEN_ARGS = {
    test: ->( value ){
      report( t.forms.errors[ scalar? ? :odd_value : :odd_array, value, self ] ) unless value.to_i.even?
    }
  }
```

In either case,
if set correctly,
the inflection filter will pick up the last argument provided and choose the appropriately inflected message.
Now let's see how exactly is this done.

### Inflection Filter

The R18n suite includes flexible filtering support for additional processing of the translated texts.
See the [R18n] documentation for example for the use of the `pl` pluralization filter.
The `FormInput` provides its own `inflect` inflection filter which works similarly.
To continue the `EVEN_ARGS` example from the previous chapter, consider the following translation file:

``` yaml
forms:
  errors:
    odd_value: !!inflect
      s: '%p is not even'
      p: '%p are not even'
    odd_array: !!inflect
      s: '%p contains number %1 which is not even'
      p: '%p contain number %1 which is not even'
```

This basically tells the R18n toolkit that it should use the `inflect` filter whenever
someone asks for the value of the `odd_value` or `odd_array` translations.
The value itself is not a string in this case,
but a hash which contains several translations.
The key is the longest prefix of the _inflection string_
used to choose the desired translation.
Now what is this inflection string and where does it come from?

Each parameter has the `inflection` method which returns
the desired string used to choose the appropriately inflected error message.
By default, it returns the grammatical number and grammatical gender strings combined,
as returned by the `plural` and `gender` methods of the parameter, respectively.
If needed, it can be also set directly by the `:inflect` parameter option.
This can be handy for languages which have even more complex rules for inflection
than the currently builtin ones.

The inflection filter checks the last parameter it was passed to the translation getter by its caller.
If it is a string, it is used as it is.
If it is a form parameter, its `inflection` method is used to get the inflection string.
If no inflection string is provided, it falls back to the default string `'sn'` which stands for singular neuter.
It than uses the form's `find_inflection` method to find the most appropriate translation for given inflection string.
By default,
it finds the longest prefix among the keys of the available translations which match the inflection string.

This may sound complex, but it allows minimizing the number of inflected translations.
Instead of having to list translations for all inflection variants,
only those which differ have to be listed and the other ones can be merged together.
In English it makes little difference,
as it only distinguishes between singular and plural grammatical case,
but you can check the translation files for other languages in the `form_input/r18n` directory
to see how this is used in practice.
Here is an excerpt from the Czech translation file which demonstrates this:

``` yaml
  required_scalar: !!inflect
    sm: '%p je povinný'
    sf: '%p je povinná'
    sn: '%p je povinné'
    p: '%p jsou povinné'
    pma: '%p jsou povinní'
    pn: '%p jsou povinná'
```

As you can see, there are three distinct variants in the singular case, one for each gender.
The plural case on the other hand uses the same variant for most genders, with only two specific exceptions defined.

Defining translations like this may seem complex,
but it should feel fairly natural to people fluent in given language.
If you intend to use some texts over and over again,
paying attention to their proper inflection will definitely pay off in the long term.

### Localizing Form Steps

If you are using the [Multi-Step Forms](#multi-step-forms),
you will likely want to localize the step names themselves as well.
Fortunately, it's very simple.
Just add the translations of all step names 
to the `steps` namespace of the form in question.

For example,
here is how the translation file of the `PostForm` form
from the [Defining Multi-Step Forms](#defining-multi-step-forms) chapter
would look like:

``` yaml
  post_form:
    email:
      title: Email
    first_name:
      title: First Name
    last_name:
      title: Last Name
    street:
      title: Street
    city:
      title: City
    zip:
      title: ZIP Code
    message:
      title: Your Message
    comment:
      title: Optional Comment
    steps:
      email: Email
      name: Name
      address: Address
      message: Message
      summary: Summary
```

Trivial indeed, isn't it?

### Supported Locales

The `FormInput` currently includes translations of builtin error messages for the following languages:

* English
* Czech
* Slovak
* Polish

To add support for another language,
simply copy the content of one of the most similar files found in the `form_input/r18n` directory
to the appropriate translation file in your project,
and translate it as you see fit.
Pay extra attention to the proper use of the inflection keys,
see the [Inflection Filter](#inflection-filter) chapter for details.
Once you are happy with the translation,
please consider sharing it with the rest of the world.
If you get in touch and make it available, it may become included in the future update of this gem.
Thanks for that.

## Credits

Copyright &copy; 2015-2016 Patrik Rak

Translations contributed by
Maroš Rovňák (Slovak)
and
Eryk Dwornicki (Polish).

The `FormInput` is released under the MIT license.


[DSL]: http://en.wikipedia.org/wiki/Domain-specific_language
[REST]: https://en.wikipedia.org/wiki/Representational_state_transfer
[AJAX]: https://en.wikipedia.org/wiki/Ajax_(programming)
[Sinatra]: http://www.sinatrarb.com/
[Ramaze]: http://ramaze.net/
[Slim]: https://github.com/slim-template/slim
[HAML]: http://haml.info/
[Bootstrap]: http://getbootstrap.com/
[DRY]: https://en.wikipedia.org/wiki/Don%27t_repeat_yourself
[ARIA]: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA
[R18n]: https://github.com/ai/r18n
[I18n]: https://github.com/svenfuchs/i18n
[sinatra-r18n]: https://github.com/ai/r18n/tree/master/sinatra-r18n
[r18n-rails]: https://github.com/ai/r18n/tree/master/r18n-rails
[Rails]: http://rubyonrails.org/
[YAML]: http://yaml.org/
[Sequel]: http://sequel.jeremyevans.net/
