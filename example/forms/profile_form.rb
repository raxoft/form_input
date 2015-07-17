# Profile form.

require_relative 'signup_form'

class ProfileForm < FormInput

  copy SignupForm[ :first_name, :last_name ]
  
  param :company, "Company"
  param :street, "Street"
  param :city, "City"
  param :state, "State", STATE_ARGS
  param :country, "Country", COUNTRY_ARGS
  param :zip, "ZIP code", ZIP_ARGS
  param :phone, "Phone number", PHONE_ARGS
  param :fax, "Fax number", PHONE_ARGS
  param :url, "URL", WEB_URL_ARGS
  
end

# EOF #
