# New password form.

require_relative 'password_form'

class NewPasswordForm < FormInput

  copy PasswordForm, title: "New password"

  param! :password_check, "Repeated password", type: :password,
    filter: self[ :password ].filter,
    check: ->{ report( "%p must match password" ) unless value == form.password }

end

# EOF #
