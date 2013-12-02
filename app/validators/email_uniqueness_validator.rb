require 'mail'
class EmailUniquenessValidator < ActiveModel::EachValidator
  
  def validate_each(record,attribute,value)
    return if record.allow_duplicate
    return unless record.contact.present?
    r = Contact.any_of({'_id' => {'$ne' =>record.contact._id}, 'contact_attributes._type' => 'Email', 'contact_attributes.value' => value})

    record.errors[attribute] << (options[:message] || "is not unique") if r.count > 0
  end
end
