# Form input

Form input is a gem which helps dealing with web request input and with creation of HTML forms.

Install the gem:

``` shell
gem install form_input
```

Describe your forms in a [DSL](http://en.wikipedia.org/wiki/Domain-specific_language)
like this:

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
        == render_snippet :form_panel, params: @form.params
        button.btn.btn-default type='submit' Send
```

The `FormInput` class will take care of sanitizing the input,
converting it into any desired internal representation,
validating it, and making it available in a model-like structure.
The provided template snippets will take care of rendering the form parameters
as well as any errors detected back to the user.
You just get to use the input and control the flow the way you want.
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
  * [Parameter Options](#parameter-options)
* [Form Templates](#form-templates)
* [Multi-Step Forms](#multi-step-forms)
* [Localization](#localization)

## Form Basics

This chapter explains how to describe your forms using a DSL,
what's the difference between internal and external representation,
how to create form instances and how to deal with errors,
and, finally, how to access the form input itself.

### Defining Parameters

To create a form, simply inherit from `FormInput` and then
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
Such parameters are required to appear in the input and have non-empty value.
Failure to do so will be automatically reported as an error
(discussed further in [Errors and Validation](#errors-and-validation)).

Both methods actually take the optional _options_ as their last argument, too.
The _options_ is a hash which is used to control
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
and we will discuss each in turn as we go.
Comprehensive summary for an avid reader is however available in [Parameter Options](#parameter-options).

The value of each parameter is string by default (or `nil` if the parameter is not set).
The string size is implicitly limited to 255 characters and bytes by default.
To limit the size explictly, you can use an optional _size_ parameter like this:

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
By default, all parameters use a filter which squeezes any whitespace into single space
and then strips the leading and trailing whitespace entirely.
This way the string input is always nice and clean even if the user types some extra spaces somewhere.
For passwords, though, we want to preserve the characters as they are, including spaces.
We could do that by simply setting the `:filter` option to `nil`.
However, at the same time we want to get rid of the trailing newline character
which is often appended by the browser
when the user cuts and pastes the password from somewhere.
Not doing this would make the password fail for no apparent reason,
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
based on available user permissions by defining `is_forbidden?` accordingly:

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

This works since you can actually pass several hashes in place of the _options_ parameter
and they all get merged together from left to right.
This allows you to mix various presets together and then tweak them further as needed.

### Internal vs External Representation

Now when you know how to define some parameters,
let's talk about the parameter values a bit.
For this, it is important that you understand
the difference between its internal and external representation.

The internal representation, as you might have guessed,
are the parameter values which you will use in your application.
The external representation is how the parameters are present
to the browser via HTML forms or URLs
and passed back to the the server.

Normally, both forms are the same.
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
which is used to preprocess the string the way we want.
The truth is that the filter doesn't have to return a string, though.
It can return any object type you want.

For example, you could choose any of the following filters
to automatically convert input values into integers (but don't do that yet):

``` ruby
  filter: ->{ to_i }
  filter: ->{ Integer( self ) rescue self }
  filter: ->{ Integer( self, 10 ) rescue self }
```

The first filter will blindly convert any string into integer.
If you want to make sure the user didn't make a typo in their input, this is not what you want.

The second filter is more strict and allows only valid numbers to be converted.
It even allows the `0x` prefix for hexadecimal numbers, which is nice,
but leading zero makes the string to be treated as an octal number,
which is likely not what you want either.

Finally, the third filter explicitly allows only decimal numbers,
regardless of leading zeros - this is likely what you want most of the time.
But this also illustrates that sometime you might want to choose otherwise.

Now in case the conversion would fail
(which is possible only in case of the second and third filter shown above),
the filters use the `rescue` clause to make sure the original string value is left intact.
This assures that it can be displayed to the user and edited again to fix it.
This is a really good practice -
making sure that even bad input can round trip back to the user -
so you should stick to it whenever possible.

However, the fact that such a filter returns a string as a result
doesn't mark the input value as invalid on its own.
Remember that many filters actually return strings intentionally.
The parameter must be first told what the correct filter output is supposed to be,
if it is expected to distinguish right from wrong and mark the wrong as an error.
That's why it has a parameter option `:class` which is designed just for that.
Proper integer filter should thus look more like this (still not complete, though):

``` ruby
  filter: ->{ Integer( self, 10 ) rescue self },
  class: Integer
```

This will make sure the parameter will be marked as invalid
if the filter fails to create an integer from the input string.
The `:class` option can actually take an array of classes,
so you can check even for boolean values with `[TrueClass, FalseClass]` easily.

But now you may be wondering, what if the parameter is not mentioned in the input at all?
Or if it is an empty string? Will that be an error?

The good news is that you don't have to worry about missing parameters.
Parameters which are not present in the request input are never passed through a filter
and their value remains set to their default `nil` value.

Empty strings on the other hand are normally passed through the filter,
so their value would remain an empty string.
That's intentional, as this normally allows you to distinguish these two cases.

If we mark the parameter as required by using either `param!` or the `:required` option,
both cases will be appropriately reported as an error.
That works fine.

But if the parameter is optional,
it would be silly to report a conversion error (or in fact any other error)
when the user submits the form without typing in any number at all.
For this reason, regardless of the `:class` desired or anything else,
both `nil` and empty string are always considered a valid parameter value as long as the parameter is optional.
Which works fine in most cases, at least as far as the form itself is concerned.

However, in this particular case it would be quite inconvenient
to have to deal with an empty string in addition to `nil`
when your code just wants an integer.
That's why we prefer to take care of an empty string in the filter ourselves and turn it into `nil`.
The complete filter for converting numbers to integers should thus look like this:

``` ruby
  filter: ->{ ( Integer( self, 10 ) rescue self ) unless empty? },
  class: Integer
```

You can even consider using `strip.empty?` if you want to allow the spurious whitespace
to be consumed silently.

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

The whole point of this lengthy explanation was just to show you how the input filters work.
The lesson learned here should be:

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

But the use of a formatter is more than just mere cosmetics.
You will often use the formatter to complement your input filter.
For example, you may want to process credit card expiration like this:

``` ruby
  EXPIRY_ARGS = {
    placeholder: 'MM/YYYY',
    filter: ->{ FormInput.parse_time( self, '%m/%y' ) rescue FormInput.parse_time( self, '%m/%Y' ) rescue self },
    format: ->{ strftime( '%m/%Y' ) rescue self },
    class: Time,
  }
  param :expiry, EXPIRY_ARGS
```

Note that the formatter won't be called if the parameter value is `nil`
or if it is already a string when it should be other type
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

So, there are the `:filter` and `:format` options to convert parameter values
from external to internal representation and back. So far so good.
But the truth is that the `FormInput` class supports one additional input transformation.
This transformation is set with the `:transform` option
and is invoked after the `:filter` filter.
So, what's the difference between `:filter` and `:transform`?

For scalar values, like normal string or integer parameters, there is none.
In that case the `:transform` is just an additional filter,
and you are free to use either or both.
But `FormInput` class supports also array and hash parameters,
as we will learn in the very next chapter,
and that's where it makes the difference.
The input filter is used to convert each individual element,
whereas the input transformation operates on the entire parameter value,
and can thus process the entire array or hash as a whole.

What you use the input transformation for is up to you.
The `FormInput` class however comes with a predefined `PRUNED_ARGS` transformation
which converts an empty string value to `nil` and prunes `nil` and empty elements from arrays and hashes,
ensuring the resulting input is free of clutter.
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
The array parameters additionaly support the `:min_count` and `:max_count` options,
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
  array :ids, INTEGER_ARGS, transform: ->{ compact.sort }
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
so you don't leave yourself open to nasty suprises.

While practical use of hash parameters with forms is fairly limited,
so you will most likely only use them with URL based non-form input, if ever,
the array parameters are pretty common.
The examples above could be used for gathering list of input fields into single array,
which is useful as well,
but the most common use of array parameters is for multi-select or multi-checkbox fields.

To declare a select parameter, you can set the `:type` to `:select` and
use the `:data` option to provide an array of values for the select menu.
The array contains pairs of parameter values to use and the corresonding text to show to the user.
For example, using a Sequel-like `Country` model:

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
Note that web request syntax supports arbitrarily nested hash and array attributes.
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
while any other argument is passed to the `set_from_request` method,
so the above is equivalent to this:

``` ruby
  form = ContactForm.new.set_from_request( request )
```

There is a fundamental difference between the `set` and `set_from_request` methods
which you must understand.
The former takes parameters in their internal representation and applies no input processing,
while the latter takes parameters in their external representation and applies input filtering and transformations to them.
It also conveniently ignores any input parameters which the form doesn't define.
On the contrary,  the `set` method can be used to set any attributes of the instance,
even those which are not the form parameters.

So make sure you use the `set_from_request` method explicitly
if you have a hash with parameters in their external representation which you want processed,
for example if you want to use Sinatra's `params` hash for some reason:

``` ruby
  form = ContactForm.new( params )                   # NEVER EVER DO THIS!
  form = ContactForm.new.set_from_request( params )  # Do this instead.
```

If you later decide to clear some parameters, you can use the `clear` method.
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
Note that FormInput normally reports only the first error detected per parameter,
but you can report arbitrary number of custom errors for given parameter
using the `report` method.
This comes handy as it allows you to pass the form into your models
and let them report any belated additional errors which might get detected during the transaction,
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
  form.errors          # => { email: [ "Email address is already taken" ] }
  form.error_messages  # => [ "Email address is already taken" ]
```

You can get all errors or first error for given parameter by using
the `errors_for` or `error_for` method, respectively:

``` ruby
  form.errors_for( :email )  # => [ "Email address is already taken" ]
  form.error_for( :email )   # => "Email address is already taken"
```

As we have seen, you can test the validity of the entire form with `valid?` or `invalid?` methods.
You can use those methods for testing validity of given parameter or parameters, too:

``` ruby
  form.valid?
  form.invalid?
  form.valid?( :email )
  form.invalid?( :name, :message )
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
until you change any of the parameter values with `set`, `clear` or `[]=`,
or explicitly run `validate!`.
Copies created with `dup` (but not `clone`), `only`, and `except` methods
also have any errors reported before cleared.
All this ensures you automatically get consistent validation results anytime you ask for them.
The only exception is when you set the parameter values explicitly using their setter methods.
This intentionally leaves the errors reported intact,
allowing you to adjust the parameter values
without interferring with the validation results.
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
The form provides all parameter names via its `param_names` or `parameter_names` methods,
so you can do this:

``` ruby
  form.param_names.each{ |name| puts "#{name}: #{form[ name ].inspect}" }
```

Sometimes, you may want to use some chosen parameters as long as they are all valid,
even if the entire form may be not.
You can do this by using the `valid` method,
which returns the valid values only if they are all valid.
Otherwise it returns `nil`.

``` ruby
  return unless email = form.valid( :email )
  first_name, last_name = form.valid( :first_name, :last_name )
```

To find out if any parameter values are filled at all, you can use the `empty?` method:

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
  p.errors        # => [ "This is invalid" ]
  p.error         # => "This is invalid"
```

You can also simply ask whether the parameter is valid or not by using the `valid?` and `invalid?` methods.
In fact, the parameter has a dozen of simple boolean getters like this which you can use to ask it about many things:

``` ruby
  p.valid?        # parameter has no errors reported?
  p.invalid?      # parameter has some errors reported?

  p.blank?        # value is nil or empty or whitespace only string?
  p.empty?        # value is nil or empty?
  p.filled?       # value is neither nil nor empty?

  p.untitled?     # parameter has no title?
  p.titled?       # parameter has a title?

  p.required?     # parameter is required?
  p.optional?     # parameter is not required?

  p.disabled?     # parameter is disabled?
  p.enabled?      # parameter is not disabled?

  p.hidden?       # parameter type is :hidden?
  p.ignored?      # parameter type is :ignore?
  p.visible?      # parameter type is neither :hidden nor :ignore?

  p.array?        # parameter was declared as an array?
  p.hash?         # parameter was declared as a hash?
  p.scalar?       # parameter was declared as a simple param?

  p.correct?      # value matches param/array/hash kind?
  p.incorrect?    # value doesn't match parameter kind?
```

Building upon these boolean getters,
the `FormInput` instance lets you get a list of parameters of certain type.
The following methods are available:

``` ruby
  form.valid_params       # parameters with no errors reported.
  form.invalid_params     # parameters with some errors reported.
  form.blank_params       # parameters with nil, empty, or blank value.
  form.empty_params       # parameters with nil or empty value.
  form.filled_params      # parameters with some non-empty value.
  form.titled_params      # parameters with a title set.
  form.untitled_params    # parameters without a title.
  form.required_params    # parameters which are required and have to be filled.
  form.optional_params    # parameters which are not required and can be nil or empty.
  form.disabled_params    # parameters which are disabled and shall be rendered as such.
  form.enabled_params     # parameters which are not disabled and are rendered normally.
  form.hidden_params      # parameters to be rendered as hidden in the form.
  form.ignored_params     # parameters not to be rendered at all in the form.
  form.visible_params     # parameters rendered normally in the form.
  form.array_params       # parameters declared as an array parameter.
  form.hash_params        # parameters declared as a hash parameter.
  form.scalar_params      # parameters declared as a simple scalar parameter.
  form.correct_params     # parameters whose current value matches their kind.
  form.incorrect_params   # parameters whose current value doesn't match their kind.
```

Each of them simply selects the paramaters using their boolean getter of the same name.
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
Note that it returns an empty array if the parameter was not tagged.
Rather than using the tags array directly, though,
it's easier to test parameter's tags using its `tagged?` and `untagged?` methods:

``` ruby
  p.tagged?                                   # tagged with some tag?
  p.untagged?                                 # not tagged at all?
  p.tagged?( :indecent )                      # tagged with this tag?
  p.untagged?( :limited )                     # not tagged with this tag?
  p.tagged?( :indecent, :limited )            # tagged with any of these tags?
  p.untagged?( :indecent, :limited )          # not tagged with any of these tags?
```

You can get the desired parameters using the form's `tagged_params` and `untagged_params` methods, too:

``` ruby
  form.tagged_params                          # parameters with some tag.
  form.untagged_params                        # parameters with no tag.
  form.tagged_params( :indecent )             # parameters tagged with this tag.
  form.untagged_params( :limited )            # parameters not tagged with this tag.
  form.tagged_params( :indecent, :limited )   # parameters with either of these tags.
  form.untagged_params( :indecent, :limited ) # parameters with neither of these tags.
```

What you use this for is up to you.
We will see later that multistep forms for example use this for grouping parameters which belong to individual steps,
but it has plenty other uses as well.

#### URL Helpers

The `FormInput` is primarily intended for use with forms,
which we will discuss in detail in [Form Templates](#form-templates),
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

  input.to_hash       # => { query: "abc", feeds: [ 1, 7 ] }
  input.url_params    # => { q: "abc", feeds: [ "1", "7" ] }
  input.url_query     # => "q=abc&feeds[]=1&feeds[]=7"
```

Unless you want to construct the URL yourself,
you can use the `extend_url` method to let the `FormInput` create the URL for you:

``` ruby
  input.extend_url( "/search" )          # => "/search?q=abc&feeds[]=1&feeds[]=7"
  input.extend_url( "/search?e=utf8" )   # => "/search?e=utf8&q=abc&feeds[]=1&feeds[]=7"
```

Note that this works well together with `only` and `except` methods,
which allow you to control which arguments get included:

``` ruby
  input.only( :query ).extend_url( "/search" )    # => "/search?q=abc"
  input.except( :query ).extend_url( "/search" )  # => "/search?feeds[]=1&feeds[]=7"
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

If you want to temporarily adjust some parameters just for creation of single URL,
you can use the `build_url` method, which combines current parameters with the provided ones:

``` ruby
  input.build_url( "/search", query: "xyz" )  # => "/search?q=xyz&feeds[]=1&feeds[]=7"
```

Finally, if you do not like the idea of parameter arrays in your URLs, you can use something like this instead:

``` ruby
  param :feeds,
    filter: ->{ split.map( &:to_i ) },
    format: ->{ join( ' ' ) },
    class: Array

  input.url_params    # => { q: "abc", feeds: "1 7" }
  input.url_query     # => "q=abc&feeds=1+7"
```

Just note that none of the standard array parameter validations apply in this case,
so make sure you apply your own validations using the `:check` callback if you need to.

#### Form Helpers

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
All this and more will be discussed in detail in [Form Templates](#form-templates), though.
This section just describes the form helpers themselves.

You can ask each form parameter about how it should be rendered by using its `type` method,
which defaults to `:text` if the option `:type` is not set.
Furthermore,
you can ask each form parameter for the appropriate name and value attributes
to use in form elements by using the `form_name` and `form_value` methods.
The simplest form parameters can be thus rendered in Slim like this:

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
It defaults to its title, but can be overriden with `:form_title` option.
If neither is set, the code name will be used instead.
To render it, you will use something like this:

``` slim
  label
    = p.form_title
    input type=p.type name=p.form_name value=p.form_value
```

Of course, you are free to use any other parameter method as well.
Want to render the parameter disabled?
Add some placeholder text?
It's as simple as adding this to your template:

``` slim
  input ... disabled=p.disabled? placeholder=p[:placeholder]
```

And that's about it.
Check out [Form Templates](#form-templates) if you want to see more form related tips and tricks.

### Parameter Options

This is a brief but comprehensive summary of all parameter options:

* `:name` - not really a parameter option, this can be used to change the parameter name and code name when copying form parameters,
  see [Reusing Form Parameters](#reusing-form-parameters).
* `:code` - not really a parameter option, this can be used to change the parameter code name when copying form parameters,
  see [Reusing Form Parameters](#reusing-form-parameters).
* `:title` - the title of the parameter, the default value shown in forms and error messages.
* `:form_title` - the title of the parameter to show in forms. Overrides `:title` when present.
* `:error_title` - the title of the parameter to use in error reports containing `%p`. Overrides `:title` when present.
* `:required` - flag set when the parameter is required.
* `:required_msg` - custom error message used when the required parameter is not filled in.
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
* `:tag` or `:tags` - arbitrary symbol or array of symbols used to tag the parameter with arbitrary semtantics.
  See `tagged?` in [Using Forms](#using-forms).
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
  Defaults to 255 if `:max_size` is dynamic option or less than 256.
* `:reject` - regular expression (or array thereof) which the parameter value(s) may not match.
* `:reject_msg` - custom error message used when the `:reject` check fails.
  Defaults to `:msg` message.
* `:match` - regular expression (or array thereof) which the parameter value(s) must match.
* `:match_msg` - custom error message used when the `:match` check fails.
  Defaults to `:msg` message.
* `:msg` - default custom error message used when either of `:match` or `:reject` checks fails.
* `:row` - used for grouping several parameters together, usually to render them in single row.
  See `chunked_params` in [Form Templates](#form-templates).
* `:cols` - optional custom option used to set span of parameter in single row.
  See `chunked_params` in [Form Templates](#form-templates).
* `:size` - custom option used set size of `:select` and `:textarea` parameters.
* `:subtitle` - custom option used to render additional subtitle after form title.
* `:placeholder` - custom option used for setting the placeholder attribute of the parameter.
* `:help` - custom option used to render help block explaining the parameter.
* `:text` - custom option used to render arbitrary text associated with the parameter.

Note that the last few options listed above are not used by the `FormInput` class itself,
but are instead used to pass additional data to snippets used for form rendering.
Feel free to extend this further if you need to pass additional data this way yourself.

## Form Templates

// form_title, form_name, form_value, placeholders, parameter chunking, focusing, reporting, etc.

## Multi-Step Forms

// define_steps, etc.

## Localization

// R18n, [], inflection, plural, gender, pt, ft, steps
