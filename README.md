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
# myapp.rb
get '/contact' do
  @form = ContactForm.new
  @form.set( email: user.email, name: user.full_name ) if user?
  slim :contact_form
end

post '/contact' do
  @form = ContactForm.new( request )
  return slim :contact_form unless @form.valid?
  text = @form.params.map{ |p| "#{p.title}: #{p.value}\n" }.join
  unless Email.send( settings.contact_sender, settings.contact_recipient, text )
    return slim :contact_failed
  end
  slim :contact_sent
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
