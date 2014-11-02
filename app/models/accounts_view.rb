# Account's view of contact
class AccountsView
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :contact
  belongs_to :account

  # fields in the account_view replace LocalUniqueAttributes
  field :status
  field :coefficient
  field :teacher
  field :last_seen_at

  embeds_many :contact_attributes 
  embeds_many :attachments

  validates_inclusion_of :status, :in => Contact::VALID_STATUSES, :allow_blank => true

  def primaty_attribute(type)
    self.contact_attributes.where({
      _type: type,
      primary: true
    }).first
  end

  def masked_attributes
    self.contact.accounts_views.map do |av|
      if av._id != self._id
        # map other accounts public attributes
        # map other accounts masked private attributes
      end
    end
  end
  
  # defines emails/telephones/addresses/custom_attributes/etc
  # they all return a Criteria scoping to according _type
  %W(email telephone address custom_attribute date_attribute identification contact_attachment social_network_id).each do |k|
    delegate k.pluralize, to: :contact_attributes
  end

  def mobiles
    self.contact_attributes.telephones.mobiles
  end

  def birthday
    self.date_attributes.where(category: 'birthday').first
  end
end
