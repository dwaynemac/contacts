require 'spec_helper'

describe DateAttribute do

  %W(category public year month day).each do |field|
    it { should have_field(field) }
  end

  describe "validates date" do
    let(:contact){Contact.make}
    it "allows nil year" do
      contact.contact_attributes << DateAttribute.new(year: nil, month: 5, day: 21)
      contact.should be_valid
      contact.save
      contact.reload
      contact.should be_valid
    end
    it "allow 2010-1-1" do
      contact.contact_attributes << DateAttribute.new(year: 2010, month: 1, day: 1)
      contact.should be_valid
      contact.save
      contact.reload
      contact.should be_valid
    end
    it "doesnt allow 2010-50-50" do
      da = DateAttribute.new(year: 2010, month: 50, day: 50)
      da.should_not be_valid
    end
  end

end
