# Password form.

# Separate form with only the password parameter to make it easy to include it wherever necessary.
class PasswordForm < FormInput

  # Enforce size and format of the password.
  # Note that we strip the password newline in case they cut&paste it from somewhere.

  param! :password, "Password", type: :password, min_size: 6,
    reject: /\P{ASCII}|[\t\r\n]/u,
    reject_msg: "%p may contain only ASCII characters and spaces",
    match: [ /[a-z]/i, /\d/ ],
    msg: "%p must contain at least one digit and one letter",
    filter: ->{ chomp }

end

# EOF #
