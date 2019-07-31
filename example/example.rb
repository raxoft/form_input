#! /usr/bin/env ruby
#
# Simple but functional example FormInput application for Sinatra.
#
# You will need the following gems:
#   gem install sinatra sinatra-partial slim form_input
#
# Then just run it like this:
#  ruby example.rb

require 'sinatra'
require 'sinatra/partial'
require 'slim/smart'
require 'form_input'

# The example form. Feel free to experiment with changing this section to whatever you want to test.

class ExampleForm < FormInput
  param! :email, 'Email address', EMAIL_ARGS
  param! :name, 'Name'
  param :company, 'Company'
  param! :message, 'Message', 1000, type: :textarea, size: 6, filter: ->{ rstrip }
end

# Support for snippets.

set :partial_template_engine, :slim
helpers do
  def snippet( name, opts = {}, **locals )
    partial( "snippets/#{name}", opts.merge( locals: locals ) )
  end
end

# The whole application itself.

get '/' do
  @form = ExampleForm.new( request )
  slim :form
end

post '/' do
  @form = ExampleForm.new( request )
  return slim :form unless @form.valid? and params[:action] == 'post'
  logger.info "These data were successfully posted: #{@form.to_hash.inspect}"
  slim :post
end

# Inline templates follow.

__END__

@@ layout
doctype html
html
  head
    title = @title
    meta charset='utf-8'
    meta name='viewport' content='width=device-width, initial-scale=1, shrink-to-fit=no'
    link rel='stylesheet' href='https://stackpath.bootstrapcdn.com/bootstrap/3.4.1/css/bootstrap.min.css' integrity='sha384-HSMxcRTRxnN+Bdg0JdbxYKrThecOKuH5zCYotlSAcp1+c8xmyTe9GYg1l9a69psu' crossorigin='anonymous'
    css:
      label { width: 100%; }
  body.container == yield

@@ form
.panel.panel-default
  .panel-heading
    = @title = "Example Form"
  .panel-body
    form method='post' action=request.path
      fieldset
        == snippet :form_panel, params: @form.params
        button.btn.btn-default type='submit' name='action' value='post' Submit
  - unless @form.empty?
    .panel-footer
      == partial :dump

@@ post
.panel.panel-default
  .panel-heading
    = @title = "Congratulations!"
    All inputs are valid.
  .panel-body
    == partial :dump
    form method='post' action=request.path
      == snippet :form_hidden, params: @form.params
      button.btn.btn-default type='submit' Go back
      a.btn.btn-default< href=request.path Start over

@@ dump
p These are the filled form values:
dl.dl-horizontal
  - for p in @form.filled_params
    dt = p.form_title
    dd
      code = p.value.inspect

// EOF //
