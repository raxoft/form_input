# Signup form.

require_relative 'password_form'

class SignupForm < FormInput

  # Currently we restrict names to latin based alphabets.

  param! :first_name, "First name", match: LATIN_NAMES_RE,
    msg: "Sorry, only names using latin alphabet are allowed"
  param! :last_name, "Last name", match: LATIN_NAMES_RE,
    msg: "Sorry, only surnames using latin alphabet are allowed"

  # Note that we only enforce relaxed format of the emails.
  # Real problems will be found out by verification anyway.

  param! :login, :email, "Email", EMAIL_ARGS

  # Enforce size and format of the password the same way the standard password form does.

  copy PasswordForm
  
end

# EOF #
