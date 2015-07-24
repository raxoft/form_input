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
  sent = Email.send( settings.contact_sender, settings.contact_recipient, text )
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
        == render_snippet :form_panel,
          params: @form.params,
          report: request.post?,
          focus: request.post?
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

* [Table of Contents](#table-of-contents)

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
based on available user permissions:

``` ruby
  param :avatar, "Avatar",
    disabled: ->{ not form.can_user_use?( :avatar )  }
  param :comment, "Comment", type: :textarea,
    disabled: ->{ not form.can_user_use?( :comment ) }
```

If you happen to use some option arguments often,
you can factor them out and share them like this:

``` ruby
  FEATURED_ARGS = { disabled: ->{ not form.can_user_use?( name ) } }
  param :avatar, "Avatar", FEATURED_ARGS
  param :comment, "Comment", FEATURED_ARGS, type: :textarea
```

This works since you can actually pass several hashes in place of the _options_ parameter
and they all get merged together from left to right.
This allows you to mix various presets together and then tweak them further as needed.

### Internal vs External Representation

// Covers filter, class, and format. Also param.code.
// Also transform which is a bridge to next chapter.

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

#### Input Filters

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
so you can check even for things like `[TrueClass, FalseClass]` easily.

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
  param :bool, BOOL_ARGS # pulldown style.
  param :check, CHECKBOX_ARGS # checkbox style.
```

You can check the `form_input/types.rb` source file to see how they are defined
and either use them directly as they are or use them as a starting point for your own variants.

The whole point of this lengthy explanation was just to show you how the input filters work.
The lesson learned here should be:

   * You can use filters to convert input parameters into any type you want.
   * Make sure the filters keep the original string in case of errors so the user can fix it.
   * You don't have to worry about `nil` input values in filters.
   * Just make sure you treat an empty or blank string as whatever you consider appropriate.

#### Output Formats


### Array and Hash Parameters

Covers array and hash parameters.
Also param.data.

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

Form.new, set, set_from_request, clear, only, except, dup, clone.

Note that set can also set non-parameter attributes.

Example form.clear( form.disabled_params ).

### Errors and Validation

Covers validation, errors, error_title, error reporting, etc.

### Using Forms

Covers parameter subsets, parameter testing, parameter access.

### Parameter options

Comprehensive summary.

## Form Templates

form_title, form_name, form_value, placeholders, parameter chunking, focusing, reporting, etc.

## Multi-Step Forms

define_steps, etc.

## Localization

