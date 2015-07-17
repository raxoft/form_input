# Press Release Form - example of a complex multistep form.

class PressReleaseForm < FormInput

  ### Parameters ###
  
  # Pricing plan we use for evaluating things.
  
  attr_reader :plan
  
  # Creation process steps.
  
  define_steps(
    content: "Content",
    date: "Date",
    location: "Location",
    contact: "Contact",
    keywords: "Keywords",
    quote: "Quote",
    images: "Images",
    videos: "Videos",
    website: "Web Site",
    release: "Release Date",
    channels: "Channels",
    summary: "Summary",
    post: nil,
  )
  
  # Press release itself.

  param! :title, "Title", 120, tag: :content,
    subtitle: "(Maximum 120 characters, recommended max 80 characters)",
    help: "The main title of your press release. It should be brief, clear and to the point."
  param :subtitle, "Subtitle", 160, tag: :content,
    subtitle: "(Maximum 160 characters)",
    help: "Optional but recommended. If used, make sure it's descriptive and builds on the headline."
  param! :text, "Text", 65000, max_bytesize: 65535, type: :textarea, size: 16, tag: :content,
    subtitle: ->{ "(Maximum #{plural( form.limit( :words ), 'word' )})" },
    filter: ->{ strip },
    check: ->{
      count = form.feature_count( :words, value )
      limit = form.limit( :words )
      report "Your text has #{plural( count, 'word' )}, but the limit is #{delimited( limit )}." if count > limit
    }
  
  # Date.
  
  param! :date, "Date", DATE_ARGS, tag: :date
  
  # Location.
  
  param! :city, "City", 100, tag: :location
  param :state, "State", STATE_ARGS, tag: :location
  param! :country, "Country", COUNTRY_ARGS, tag: :location
  
  # Contact info.
  
  param! :contact_name, "Full Name", 60, tag: :contact
  param! :contact_organization, "Organization Name", 60, tag: :contact
  param! :contact_phone, "Phone", 30, PHONE_ARGS, tag: :contact
  param! :contact_email, "Email Address", 60, EMAIL_ARGS, tag: :contact
  
  # Keywords.
  
  array :keywords, "Keywords", 35, PRUNED_ARGS, tag: :keywords,
    row: :keywords, cols: 5,
    max_count: ->{ form.limit( :keywords ) }
  array :keywords_urls, "Keywords URL", PRUNED_ARGS, WEB_URL_ARGS, max_count: 30, tag: :keywords,
    row: :keywords, cols: 7,
    max_count: ->{ form.limit( :keywords ) }
  
  def balance_keywords
    self.keywords ||= []
    self.keywords_urls ||= []
    
    report( :keywords, "Keywords must match the keyword URLs" ) if keywords.count < keywords_urls.count
    report( :keywords_urls, "Keyword URLs must match the keywords" ) if keywords.count > keywords_urls.count
    
    self.keywords << "" while keywords.count < keywords_urls.count
    self.keywords_urls << "" while keywords.count > keywords_urls.count
  end
  
  # Quote.
  
  param :quote, "Quote", 200, tag: :quote,
    subtitle: "(Maximum 200 characters)",
    disabled: ->{ form.disabled?( :quote ) }
  param :quote_author, "Quote Author", 100, tag: :quote,
    subtitle: "(Maximum 100 characters)",
    disabled: ->{ form.disabled?( :quote ) }
  
  # Images.
  
  array :images, "Images", PRUNED_ARGS, tag: :images,
    max_count: ->{ form.limit( :images ) }
  
  # Video.
  
  array :videos, "Videos", PRUNED_ARGS, tag: :videos,
    max_count: ->{ form.limit( :videos ) }
  
  # Website.

  param :website_url, "URL", WEB_URL_ARGS, tag: :website,
    disabled: ->{ form.disabled?( :website ) }
    
  # Release date.
  
  param :release_date, "Release Date", US_DATE_ARGS, tag: :release,
    disabled: ->{ form.disabled?( :scheduling ) }
  param :release_time, "Release Time", HOURS_ARGS, tag: :release,
    disabled: ->{ form.disabled?( :scheduling ) }
  
  # Distribution.
  
  array! :channels, "Channels", type: :select, tag: :channels,
    size: 25,
    max_count: ->{ form.limit( :channels ) },
    data: ->{ Channel.all.map{ |x| [ x.code, x.name ] } },
    filter: ->{ self if Channel[ self ] }

  ### Methods ###
  
  # Initialize new instance.
  def initialize( plan, *args )
    @plan = plan
    super( *args )
    balance_keywords
  end
  
  # Get the items to show in the sidebar.
  def sidebar_items
    { base: 'Base Price' }.merge( step_names )
  end
  
  # Get limit for given feature.
  def limit( feature )
    plan.extra_limit( feature )
  end
  
  # Get count for given feature and value.
  def feature_count( feature, value )
    plan.feature_count( feature, value )
  end
  
  # Test if given feature is disabled for current plan.
  def disabled?( feature )
    not plan.has_feature?( feature )
  end
  
end

# EOF #
