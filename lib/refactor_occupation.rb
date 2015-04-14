# class to gather all occupations
# stored in custom_attributes and
# move them to the new Occupation ContactAttribute
class RefactorOccupation
  module HelperMethods

    def move_occupation(contact)
      custom_occupations_for(contact).update_all(
        _type: 'Occupation',
        name: nil
      )
    end

    def custom_occupations_for(contact)
      contact.contact_attributes
             .where( _type: 'CustomAttribute')
             .where( '$or' => [
               {name: /prof/i},
               {name: /ocu/i}
             ])
    end

    def occupation_keys(scope=nil)
      (custom_keys_matching(/prof/i) + custom_keys_matching(/ocu/i))
      #  ["Profesion", "profissão", "Profesión", "Profissão ", "Profissão"]
      #  ["Ocupación", "Ocupación ", "Ocupaçao"]
    end

    def custom_keys_matching(regex)
      Contact.where(contact_attributes: { '$elemMatch' => { _type: 'CustomAttribute', name: regex} })
             .limit(2000)
             .map{|c| c.custom_attributes.where(name: regex).map{|ca| ca.name} }.flatten.uniq

    end

    def contacts_with_occupation
      Contact.where(contact_attributes: { '$elemMatch' => {
        "$and" => [
          {_type: 'CustomAttribute'},
          {
            "$or" => [
               {name: /prof/i},
               {name: /ocu/i}
            ]
          }
        ]
      }})
    end
  end
  extend HelperMethods

  def self.doit
    contacts_with_occupation.each do |contact|
      move_occupation(contact)
    end
  end
end
