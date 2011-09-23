# Local version of Padma Account
# Contacts specific configuration could be stored on this model.
class Account
  include Mongoid::Document

  field :name

  has_many :owned_contacts, :foreign_key => :owner_id, :class_name => "Contact"

  has_many :lists, :autosave => true

  validates :name, :presence => true, :uniqueness => true, :existance_on_padma => true

  before_create :create_base_list

  protected

  def create_base_list
    if lists.empty?
      lists << List.create(:name => self.name)
    end
  end
end
