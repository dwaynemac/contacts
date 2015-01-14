require 'mail'
class EmailUniquenessValidator < ActiveModel::EachValidator
  
  def validate_each(record,attribute,value)
    return if record.allow_duplicate
    return unless record.contact.present?
    r = Contact.any_of({
      '_id' => {'$ne' =>record.contact._id},
      contact_attributes: { '$elemMatch' => {
        '_type' => 'Email',
        value: value
        } 
    }})
    if r.count > 0
      record.errors[attribute] << (options[:message] || I18n.t('errors.messages.is_not_unique'))
      record.errors[:possible_duplicates] << r.map {|c| c.minimum_representation}
    end
  end
end