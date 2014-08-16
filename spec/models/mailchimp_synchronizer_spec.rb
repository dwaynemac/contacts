require 'spec_helper'

describe MailchimpSynchronizer do
  let(:account){Account.make}
  let(:sync){MailchimpSynchronizer.new(account: account)}

  describe "#get_primary_attribute_value" do
    describe "if contact has none" do
      let(:contact){Contact.make}
      it "returns nil" do
        expect(sync.get_primary_attribute_value(contact,'Email')).to be_nil
      end
    end
    describe "if contact has" do
      let(:contact){Contact.make}
      let(:email_value){'dwa@sd.co'}
      before do
        contact.contact_attributes << Email.make(account: account, value: email_value)
      end

      it "returns the value" do 
        expect(sync.get_primary_attribute_value(contact,'Email')).to eq email_value
      end
    end
  end
end
