# @example
#   sl = account.smart_lists.new(name 'All Dwaynes', query: Contact.where(first_name: 'Dwayne').scoped )
#   sl.contacts
class SmartList
  include Mongoid::Document

  belongs_to :account

  field :name, type: String
  field :query, type: Hash

  # @note this method is memoized
  # @return [Array<Contact>] contacts
  def contacts
    @contacts ||= self.to_criteria
  end

  def to_criteria
    Mongoid::Criteria.new(Contact).fuse(query)
  end

end
