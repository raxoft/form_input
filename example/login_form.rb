# Login form.

class LoginForm < FormInput

  # Note that we intentionally don't impose any format of these,
  # as we don't want to assume what they have registered with.
  # Only strip the password newline in case they cut&paste it from somewhere.

  param! :login, :email, "Email"
  param! :password, "Password", type: :password, filter: ->{ chomp }

end

# EOF #
