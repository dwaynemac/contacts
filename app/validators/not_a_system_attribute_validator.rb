class NotASystemAttributeValidator < ActiveModel::EachValidator
  def validate_each(record,attribute,value)
    if value && value.downcase.in?(ContactAttribute::TYPES)
      record.errors[attribute] = (options[:message] || 'restricted value')
    end
  end
end
