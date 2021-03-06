require File.dirname(__FILE__) + '/../spec_helper'

describe ContactAttribute do
  it { should have_field(:public).of_type(Boolean) }
  it { should have_field(:primary).of_type(Boolean) }
  it { should have_field(:value).of_type(String) }
  it { should validate_presence_of(:value) }

  it { should belong_to_related :account }

  describe "as_json" do
    let(:jsonh){@c.contact_attributes.last.as_json}
    before do
      @c = Contact.make
      @c.contact_attributes << Telephone.make
    end
    it "should include _type if no options are given" do
      jsonh["_type"].should_not be_nil
    end
    it "should consider options" do
      @c.contact_attributes.last.as_json(exclude: [:value])[:value].should be_nil
    end
    it "should show account_name" do
      jsonh.should have_key 'account_name'
    end

    it "should show public boolean" do
      jsonh.should have_key 'public'
    end

    it "should show primary boolean" do
      jsonh.should have_key 'primary'
    end

    it "includes _id as a string" do
      expect(jsonh['_id']).to be_a String
    end

    it "includes contact_id as string" do
      expect(jsonh['contact_id']).to be_a String
    end
  end

  describe "readonly" do
    specify "model marked readonly should not be saved" do
      contact = Contact.make_unsaved()
      contact.contact_attributes << Telephone.make
      contact.contact_attributes.last.readonly!
      lambda{contact.save}.should raise_error("ReadOnly")
    end
    specify "model not-marked readonly should save normally" do
      contact = Contact.make
      t = Telephone.make_unsaved
      contact.contact_attributes << t
      contact.should be_valid
    end
  end

  describe "#for_account" do
    before do
      @empty_account = Account.make
      @ok_account = Account.make
      @contact = Contact.make(:owner => @ok_account)
      @contact.contact_attributes << ContactAttribute.make(:account => @ok_account)
      @contact.save
    end

    it "should return the attributes corresponding to the account" do
      @contact.contact_attributes.for_account(@ok_account).should_not be_empty
    end

    it "should return public attributes" do
      @contact.contact_attributes.first.public = true
      @contact.save
      @contact.contact_attributes.for_account(@empty_account).should_not be_empty
    end

    it "should filter the attributes corresponding other accounts" do
      @contact.contact_attributes.for_account(@empty_account).should be_empty
    end

    context "with option :include_masked" do
      context "for phone 12345678" do
        before do
          @contact.contact_attributes << Telephone.make(value: "12345678", public: false, account: @ok_account)
          @contact.save
          @contact.reload
        end

        it "should return an array" do
          @contact.contact_attributes.for_account(@empty_account, :include_masked => true).should be_a(Array)
        end
        it "should return ####5678 for non-owner accounts" do
          attrs = @contact.contact_attributes.for_account(@empty_account, :include_masked => true)
          attrs.should_not be_empty
          attrs.last.should be_a(ContactAttribute)
          attrs.last.value.should == "####5678"
        end
        it "should return 12345678 for owner account" do
          attrs = @contact.contact_attributes.for_account(@ok_account, :include_masked => true)
          attrs.should_not be_empty
          attrs.last.value.should == "12345678"
        end

        it "should not duplicate values" do
          @contact.contact_attributes << Telephone.make(value: "12345678", public: false, account: @empty_account)
          @contact.save
          @contact.reload
          attrs = @contact.contact_attributes.for_account(@empty_account, :include_masked => true)
          attrs.size.should == 1
          attrs.last.value.should == "12345678"
        end
      end
    end
  end

  describe "When created" do
    before do
      @account = Account.make
      @contact = Contact.make(:owner => @account)
      @contact.contact_attributes << ContactAttribute.make(:account => nil)
      @contact.save
    end

    it "should be owned by contact owner if not specified" do
      @contact.contact_attributes.first.account.should == @account
    end
  end

  describe "can be primary." do
    let(:contact){Contact.make}
    let(:account){Account.make}
    it { should have_field(:primary).of_type(Boolean) }
    specify "When primary is set, any other primary-attribute of same account and category stops being primary" do
      Email.make(primary: true, contact: contact, account: account)
      new_e = Email.make(primary: false, contact: contact, account: account)
      new_e.primary = true
      new_e.save
      contact.reload
      contact.emails.first.should_not be_primary
      contact.emails.last.should be_primary
    end
    specify "The set of attributes that share account and type must have one and only one primary element" do
      (1..3).each do
        contact.contact_attributes << Email.make_unsaved(primary: false, contact: contact, account: account)
      end
      contact.save
      contact.reload
      contact.emails.where(:primary => true).count.should == 1
    end
    let(:other_account){Account.make}
    specify "The set of attributes that share account and type must have at least one primary element" do
      contact.save
      ca = contact.contact_attributes.new(value: "test00@mail.com", primary: true)
      ca._type= 'Email'
      ca.account = other_account
      ca.save
      (1..3).each do |i|
        # create the same way controller does
        ca = contact.contact_attributes.new(value: "test#{i}@mail.com", primary: false)
        ca._type= 'Email'
        ca.account = account
        ca.save
      end
      contact.reload
      expect(contact.emails.count).to eq 4
      expect(contact.emails.where(primary: true).count).to eq 2
      expect(contact.emails.where(account_id: account.id, primary: true).count).to eq 1
    end
  end

  describe "Primary attributes must be accesible by contact.primary_attribute" do
    before do
      @account = Account.make
      @contact = Contact.make(:owner => @account)
      @contact.contact_attributes << Telephone.new(:account => @contact.owner, :category => :home, :value => "12343210")
      @contact.save
      @contact.reload
    end

    it "should be accesible" do
      @contact.primary_attribute(@account, 'Telephone').value.should == "12343210"
    end

    it "should be updated if new primary is saved" do
      @contact.contact_attributes << Telephone.new(
        :account => @contact.owner,
        :category => :home,
        :value => "11235813",
        :primary => true
      )
      @contact.primary_attribute(@account, 'Telephone').value.should == "11235813"
    end
  end
end
