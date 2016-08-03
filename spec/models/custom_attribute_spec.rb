require 'spec_helper'

describe CustomAttribute do

  it "wont allow ContactAttribute system types as name" do
    ContactAttribute::TYPES.each do |cctype|
      ca = CustomAttribute.new(name: cctype)
      ca.valid?
      expect(ca.errors.messages[:name]).to eq ["restricted value"]
    end
  end
  it "allows name not in system types" do
    ContactAttribute::TYPES.each do |cctype|
      ca = CustomAttribute.new(name: "#{cctype}a")
      ca.valid?
      expect(ca.errors.messages[:name]).to be_blank
    end
  end
  describe ".custom_keys" do
    let(:account){Account.make}
    context "if account has custom keys" do
      before do
        c = Contact.make
        c.link(account)
        c.contact_attributes << CustomAttribute.new(value: 'as',
                                                    name: 'first-custom-key',
                                                    account: account)
        c.save!

        c = Contact.make
        c.link(account)
        c.contact_attributes << CustomAttribute.new(value: 'as',
                                                    name: 'second-custom-key',
                                                    account: account)
        c.save!
      end
      it "returns an array with account's custom keys" do
        expect(CustomAttribute.custom_keys(account).count).to eq 2
        expect(CustomAttribute.custom_keys(account)).to eq %W(first-custom-key second-custom-key)
      end
      it "wont consider unlinked contacts" do
        c = Contact.make
        c.contact_attributes << CustomAttribute.new(value: 'as',
                                                    name: 'custom-key-in-unlinked-contact',
                                                    account: account)
        c.save!
        account.unlink(c)
        expect(CustomAttribute.custom_keys(account)).not_to include 'custom-key-in-unlinked-contact'
      end
      it "wont include other accounts keys" do
        c = Contact.make
        c.link(account)
        c.contact_attributes << CustomAttribute.new(value: 'as',
                                                    name: 'other-custom-key',
                                                    account: Account.make)
        c.save!

        expect(CustomAttribute.custom_keys(account)).not_to include 'other-custom-key'
      end
      it "wont repeat keys" do
        c = Contact.make
        c.link(account)
        c.contact_attributes << CustomAttribute.new(value: 'as',
                                                    name: 'second-custom-key',
                                                    account: account)
        c.save!

        expect(CustomAttribute.custom_keys(account)).to eq %W(first-custom-key second-custom-key)
      end
    end
    context "if account has no custom keys" do
      it "returns an empty array" do
        expect(CustomAttribute.custom_keys(account)).to be_a Array
        expect(CustomAttribute.custom_keys(account)).to be_empty
      end
    end
  end
end
