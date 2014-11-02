# Accounts view of contact
#
# c = Contact.find('asdf')
class AccountsView
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :account

  # fields in the account_view replace LocalUniqueAttributes
  field :status
  field :coefficient
  field :teacher
  field :last_seen_at

  # todo how to "publish public attributes"??
  embeds_many :contact_attributes 
  embeds_many :attachments

end
