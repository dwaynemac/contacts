require File.dirname(__FILE__) + '/../spec_helper'

describe "Scoping contact attributes with account" do
  it "routes v0/accounts/:account_name/contact_attributes/:id to contact_attributes#update for account_name" do
    { :put => "v0/accounts/account_name/contact_attributes/1" }.should route_to(
      :controller => "v0/contact_attributes",
      :action => "update",
      :account_name => "account_name",
      :id => "1"
    )
  end
end