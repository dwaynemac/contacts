require 'spec_helper'

describe RefactorOccupation do
    def add_key(contact,key)
      contact.contact_attributes << CustomAttribute.new(
          name: key,
          value: 'blah'
      )
      contact.save!
    end

  describe "custom_keys_matching" do
    let(:contact){ Contact.make }

    it "lists all custom_attributes names matching given regex" do
      add_key(contact,'Profesion')
      add_key(contact,'Proffession')
      expect(RefactorOccupation.custom_keys_matching(/prof/i))
        .to eq ['Profesion','Proffession']
    end

    it "returns empty array if no key matches regex" do
      expect(RefactorOccupation.custom_keys_matching(/prof/i))
        .to eq []
    end

  end

  describe "contacts_with_occupation" do
    let(:contact){ Contact.make }
    it "returns contacts with occupation as a custom attribute" do
      add_key(contact,'profesion')
      expect(RefactorOccupation.contacts_with_occupation.to_a).to eq [contact]
    end
  end
end
