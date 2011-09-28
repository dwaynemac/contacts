require 'padma_account'
class ExistanceOnPadmaValidator < ActiveModel::EachValidator
  def validate_each(record,attribute,value)
    return if !record.new_record? && !record.name_changed?
    if !PadmaAccount.find(record.name)
      record.errors.add(:name,I18n.t('account.padma_account_not_found'))
    end
  end
end
