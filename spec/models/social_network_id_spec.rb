require File.dirname(__FILE__) + '/../spec_helper'

describe SocialNetworkId do
  let!(:contact){Contact.make}

  describe "when category is facebook" do
    let(:category){'facebook'}
    describe "if URL is given" do
      let(:value){'https://www.facebook.com/juan.c.quicosta?fref=ufi'}
      it "converts it to id" do
        sni = SocialNetworkId.make_unsaved(value: value, category: category)
        contact.contact_attributes << sni
        contact.save
        expect(contact.reload.contact_attributes.first.value).to eq 'juan.c.quicosta'
      end
    end
    describe "if id is given" do
      let(:value){'dwaynemac'}
      it "stores it unchanged" do
        sni = SocialNetworkId.make_unsaved(value: value, category: category)
        contact.contact_attributes << sni
        contact.save
        expect(contact.reload.contact_attributes.first.value).to eq 'dwaynemac'
      end
    end
  end

  describe "when category is twitter" do
    let(:category){'twitter'}
    describe "if URL is given" do
      let(:value){'http://www.twitter.com/#!/donttrythis'}
      it "converts it to id" do
        sni = SocialNetworkId.make_unsaved(value: value, category: category)
        contact.contact_attributes << sni
        contact.save
        expect(contact.reload.contact_attributes.first.value).to eq 'donttrythis'
      end
    end
    describe "if id is given" do
      let(:value){'dwaynemac'}
      it "stores it unchanged" do
        sni = SocialNetworkId.make_unsaved(value: value, category: category)
        contact.contact_attributes << sni
        contact.save
        expect(contact.reload.contact_attributes.first.value).to eq 'dwaynemac'
      end
    end
  end
end
