# Provides methods:
#
# * account_name
# * account_name=(string)
#
# This module expect the class to have an attr_accessor :account [Account]
module AccountNameAccessor

  # This method is called multiple time in Contact serialization
  # there are extra efforts to cache it to avoid interaction with db
  # @return [String] account name
  def account_name
    if @account_name.nil?
      @account_name = Rails.cache.read(['account_name_by_id',self.account_id])
      if @account_name.nil?
        @account_name = self.account.try(:name)
        Rails.cache.write(['account_name_for_id',self.account_id],@account_name)
      end
    end
    return @account_name
  end

  # Sets account by name
  # won't create account if inexistant
  def account_name=(name)
    self.account = Account.where(name: name).first
    @account_name = self.account.try(:name)
    return @account_name
  end
end
