require File.dirname(__FILE__) + '/../spec_helper'

describe "Scoping contacts with account" do
  it "routes v0/accounts/:account_name/contacts to contacts#index for account_name" do
    { :get => "v0/accounts/account_name/contacts" }.should route_to(
      :controller => "v0/contacts",
      :action => "index",
      :account_name => "account_name"
    )
  end
end