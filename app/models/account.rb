# Local version of Padma Account
# Contacts specific configuration could be stored on this model.
class Account
  include Mongoid::Document

  field :name

  has_many :owned_contacts, :foreign_key => :owner_id, :class_name => "Contact"

  has_many :lists, :autosave => true
  has_many :smart_lists

  validates :name, :presence => true, :uniqueness => true, :existance_on_padma => true

  before_create :create_base_list

  # @return [List] base_list
  def base_list
    bl = self.lists.find_or_initialize_by(name: self.name)
    # find_or_create_by generated conflicts in some situations like: contact.rb:226
    if bl.new?
      bl.account = self
      bl.save!
    end
    bl
  end

  # All contacts included in a list of this account
  def contacts
    Contact.where('$or' => [{list_ids: {'$in' => self.lists.map(&:_id)}}, {owner_id: self._id}])
  end

  # Adds contact to base_list
  # @param contact [Contact]
  # @return [TrueClass]
  def link(contact)
    contact.lists << self.base_list
    contact.owner = self if contact.owner.nil?
    contact.save
  end

  # Removed this contact from all this accounts lists
  def unlink(contact)
    contact.lists = contact.lists.reject{|l|l.account == self}
    if contact.owner == self
      contact.owner = nil
    end
    contact.save
  end

  protected

  def create_base_list
    if lists.empty?
      lists << List.create(:name => self.name)
    end
  end
end
