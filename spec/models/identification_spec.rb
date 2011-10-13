require File.dirname(__FILE__) + '/../spec_helper'

describe Identification do
  it { should validate_presence_of :value }
end

describe Identification do
  before(:each) do
    Contact.destroy_all
  end

  it "value should be unique scoped to name (not two people with same id)"

  it "name should be unique scoped to account and person (two accounts set the same id on a person)"

end