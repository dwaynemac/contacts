require 'mail'
class EmailUniquenessValidator < ActiveModel::EachValidator
  def validate_each(record,attribute,value)
    r = Contact.any_of({'contact_attributes._type' => 'Email', 'contact_attributes.value' => value})

    record.errors[attribute] << (options[:message] || "is not unique") if r.count > 0
  end
end