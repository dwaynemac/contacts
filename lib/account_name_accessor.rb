# Provides methods:
#
# * account_name
# * account_name=(string)
#
module AccountNameAccessor
  # @return [String] account name
  def account_name
    self.account.try :name
  end

  # Sets account by name
  # won't create account if inexistant
  def account_name=(name)
    self.account = Account.where(name: name).first
  end
end