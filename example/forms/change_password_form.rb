# Change password form.

require_relative 'new_password_form'

class ChangePasswordForm < FormInput

  # Note that we intentionally don't impose any format on this,
  # as we don't want to assume what they have registered with.
  # Only strip the password newline in case they cut&paste it from somewhere.

  param! :old_password, "Old password", type: :password, filter: ->{ chomp }

  copy NewPasswordForm

end

# EOF #
