# Lost password form.

class LostPasswordForm < FormInput

  # Note that we intentionally don't impose any format of the email,
  # as we don't want to assume what they have registered with.
  # We will let them know in case we don't find it anyway.
  # We merely check if it looks like an email at all.

  param! :email, "Email", match: /@/

end

# EOF #
