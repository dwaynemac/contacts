class ContactAttribute
  include Mongoid::Document
  #include Mongoid::Timestamps

  embedded_in :contact

  # belongs_to :account
  # public?
end