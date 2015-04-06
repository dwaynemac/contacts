# class to gather all occupations
# stored in custom_attributes and
# move them to the new Occupation ContactAttribute
class RefactorOccupation
  module HelperMethods
    def occupation_keys
      custom_keys_matching(/prof/i)
    end

    def custom_keys_matching(regex)
      Contact.where(contact_attributes: { '$elemMatch' => { _type: 'CustomAttribute', name: regex} })
             .limit(2000)
             .map{|c| c.custom_attributes.where(name: regex).map{|ca| ca.name} }.flatten.uniq

    end
  end
  extend HelperMethods

  def self.contacts_with_occupation
    Contact.where(contact_attributes: { '$elemMatch' => { _type: 'CustomAttribute',
                                                          name: { '$in' => occupation_keys} }})
  end


end
