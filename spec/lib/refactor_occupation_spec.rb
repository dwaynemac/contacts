# encoding: UTF-8
require 'spec_helper'

describe RefactorOccupation do
    def add_key(contact,key,value='blah')
      contact.contact_attributes << CustomAttribute.new(
          name: key,
          value: value
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

  describe "contacts_with_occupation" do
    let(:y_contact){ Contact.make }
    let(:n_contact){ Contact.make }
    before do
      add_key(y_contact,'Profesion')
    end
    it "returns contacts with occupation as a custom_attribute" do
      expect(RefactorOccupation.contacts_with_occupation).to include y_contact
    end
    it "ignores contacts without occupation as a custom_attribute" do
      expect(RefactorOccupation.contacts_with_occupation).not_to include n_contact
    end
  end

  describe "move_occupation" do
    let(:contact){ Contact.make }
    before do
      add_key(contact,'profesion', 'lawyer')
      add_key(contact,' Proffesion', 'frontender' )
      add_key(contact,'Profesión ', 'hacker' )
      add_key(contact,'Ocupation', 'teacher' )
      RefactorOccupation.move_occupation(contact)
    end
    it "removes custom_attribute from contact" do
      expect(contact.reload.custom_attributes).to be_empty
    end
    it "creates a Occupation attribute on contact" do
      expect(contact.reload.occupations.count).to eq 4
    end
    it "keeps occupation value" do
      expect(contact.reload.occupations.map{|o| o.value}).to eq %W(lawyer frontender hacker teacher)
    end
  end
end
