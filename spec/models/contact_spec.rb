require File.dirname(__FILE__) + '/../spec_helper'

describe Contact do
  it { should embed_many :contact_attributes }

  it { should be_referenced_in :account }

  it { should have_fields :first_name, :last_name }

  it { should validate_presence_of :first_name }
end