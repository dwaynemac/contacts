class CustomAttribute < ContactAttribute
  field :name

  validate :name, :presence => true

  # @return [Array] custom keys that account uses
  def self.custom_keys(account)
    ret = nil
    scope = if account
      account.contacts.with_custom_attributes
    else
      Contact.with_custom_attributes
    end

    ActiveSupport::Notifications.instrument('map_custom_attributes.get_keys') do
      if account
        ret = scope.map{|c| c.custom_attributes.where(account_id: account.id)}
      else
        ret = scope.with_custom_attributes.map{ |c| c.custom_attributes }
      end
    end
    ActiveSupport::Notifications.instrument('flatten.get_keys') do
      ret = ret.flatten
    end
    ActiveSupport::Notifications.instrument('map_name.get_keys') do
      ret = ret.map(&:name)
    end
    ActiveSupport::Notifications.instrument('uniq.get_keys') do
      ret = ret.uniq
    end
    ret
  end
end
