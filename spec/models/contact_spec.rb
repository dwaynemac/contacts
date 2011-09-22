require File.dirname(__FILE__) + '/../spec_helper'

describe Contact do
  it { should embed_many :contact_attributes }

  it { should belong_to_related :owner }

  it { should reference_and_be_referenced_in_many :lists }

  it { should have_fields :first_name, :last_name }

  it { should validate_presence_of :first_name }
end