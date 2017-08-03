# Local version of Padma Account
# Contacts specific configuration could be stored on this model.
class AccountContact < ActiveRecord::Base
  
  belongs_to :account, :class_name => 'NewAccount'
  belongs_to :contact, :class_name => 'NewContact'

  has_objectid_columns :contact_id

  validates :account, presence: true
  validates :contact, presence: true

  # @return [String]
  def coefficient
    NewContact::VALID_COEFFICIENTS.key(read_attribute(:coefficient))
  end

  # Setter for coefficient overriden to keep integers values for proper sorting
  # @param s [String]
  def coefficient=(c)
    write_attribute(:coefficient, NewContact::VALID_COEFFICIENTS[c])
  end

end