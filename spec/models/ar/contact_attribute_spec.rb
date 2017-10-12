require 'ar_spec_helper'

describe NewContactAttribute do
  it { should respond_to(:public) }
  it { should respond_to(:primary) }

  it { should belong_to :account }
  it { should belong_to :contact }

  # describe "as_json" do
  #   let(:jsonh){@c.contact_attributes.last.as_json}
  #   before do
  #     @c = NewContact.make
  #     @c.contact_attributes << Telephone.make
  #   end
  #   it "should include _type if no options are given" do
  #     jsonh["_type"].should_not be_nil
  #   end
  #   it "should consider options" do
  #     @c.contact_attributes.last.as_json(exclude: [:value])[:value].should be_nil
  #   end
  #   it "should show account_name" do
  #     jsonh.should have_key 'account_name'
  #   end

  #   it "should show public boolean" do
  #     jsonh.should have_key 'public'
  #   end

  #   it "should show primary boolean" do
  #     jsonh.should have_key 'primary'
  #   end

  #   it "includes _id as a string" do
  #     expect(jsonh['_id']).to be_a String
  #   end

  #   it "includes contact_id as string" do
  #     expect(jsonh['contact_id']).to be_a String
  #   end
  # end

  # describe "readonly" do
  #   specify "model marked readonly should not be saved" do
  #     contact = Contact.make_unsaved()
  #     contact.contact_attributes << Telephone.make
  #     contact.contact_attributes.last.readonly!
  #     lambda{contact.save}.should raise_error("ReadOnly")
  #   end
  #   specify "model not-marked readonly should save normally" do
  #     contact = Contact.make
  #     t = Telephone.make_unsaved
  #     contact.contact_attributes << t
  #     contact.should be_valid
  #   end
  # end

  # describe "#for_account" do
  #   before do
  #     @empty_account = Account.make
  #     @ok_account = Account.make
  #     @contact = Contact.make(:owner => @ok_account)
  #     @contact.contact_attributes << ContactAttribute.make(:account => @ok_account)
  #     @contact.save
  #   end

  #   it "should return the attributes corresponding to the account" do
  #     @contact.contact_attributes.for_account(@ok_account).should_not be_empty
  #   end

  #   it "should return public attributes" do
  #     @contact.contact_attributes.first.public = true
  #     @contact.save
  #     @contact.contact_attributes.for_account(@empty_account).should_not be_empty
  #   end

  #   it "should filter the attributes corresponding other accounts" do
  #     @contact.contact_attributes.for_account(@empty_account).should be_empty
  #   end

  #   context "with option :include_masked" do
  #     context "for phone 12345678" do
  #       before do
  #         @contact.contact_attributes << Telephone.make(value: "12345678", public: false, account: @ok_account)
  #         @contact.save
  #         @contact.reload
  #       end

  #       it "should return an array" do
  #         @contact.contact_attributes.for_account(@empty_account, :include_masked => true).should be_a(Array)
  #       end
  #       it "should return ####5678 for non-owner accounts" do
  #         attrs = @contact.contact_attributes.for_account(@empty_account, :include_masked => true)
  #         attrs.should_not be_empty
  #         attrs.last.should be_a(ContactAttribute)
  #         attrs.last.value.should == "####5678"
  #       end
  #       it "should return 12345678 for owner account" do
  #         attrs = @contact.contact_attributes.for_account(@ok_account, :include_masked => true)
  #         attrs.should_not be_empty
  #         attrs.last.value.should == "12345678"
  #       end

  #       it "should not duplicate values" do
  #         @contact.contact_attributes << Telephone.make(value: "12345678", public: false, account: @empty_account)
  #         @contact.save
  #         @contact.reload
  #         attrs = @contact.contact_attributes.for_account(@empty_account, :include_masked => true)
  #         attrs.size.should == 1
  #         attrs.last.value.should == "12345678"
  #       end
  #     end
  #   end
  # end

  describe "When created" do
    before do
      @account = NewAccount.make
      @contact = NewContact.make(:owner => @account)
      @contact.contact_attributes << NewContactAttribute.make(:contact_id => @contact.id, :account => nil)
      @contact.save
    end

    it "should be owned by contact owner if not specified" do
      @contact.contact_attributes.first.account.should == @account
    end
  end

  describe "can be primary." do
    let(:contact){NewContact.make}
    let(:account){NewAccount.make}
    
    it { should respond_to(:primary) }

    specify "When primary is set, any other primary-attribute of same account and category stops being primary" do
      NewEmail.make(primary: true, contact_id: contact.id, account: account)
      new_e = NewEmail.make(primary: false, contact_id: contact.id, account: account)
      new_e.primary = true
      new_e.save
      contact.reload
      contact.emails.first.should_not be_primary
      contact.emails.last.should be_primary
    end
    specify "The set of attributes that share account and type must have one and only one primary element" do
      (1..3).each do
        contact.contact_attributes << NewEmail.make_unsaved(primary: false, contact_id: contact.id, account: account)
      end
      contact.save
      contact.reload
      contact.emails.select {|e| e.primary?}.count.should == 1
    end
    let(:other_account){NewAccount.make}
    specify "The set of attributes that share account and type must have at least one primary element" do
      contact.save
      ca = contact.contact_attributes.new(value: "test00@mail.com", primary: true)
      ca.type= 'NewEmail'
      ca.account = other_account
      ca.save
      (1..3).each do |i|
        # create the same way controller does
        ca = contact.contact_attributes.new(value: "test#{i}@mail.com", primary: false)
        ca.type= 'NewEmail'
        ca.account = account
        ca.save
      end
      contact.reload
      expect(contact.emails.count).to eq 4
      expect(contact.emails.select {|e| e.primary?}.count).to eq 2
      expect(contact.emails.select {|e| e.account_id == account.id and e.primary?}.count).to eq 1
    end
  end

  describe "Primary attributes must be accesible by contact.primary_attribute" do
    before do
      @account = NewAccount.make
      @contact = NewContact.make(:owner => @account)
      @contact.contact_attributes << NewTelephone.new(:account_id => @contact.owner_id, :category => :home, :value => "12343210")
      @contact.save
      @contact.reload
    end

    it "should be accesible" do
      @contact.primary_attribute(@account, 'NewTelephone').value.should == "12343210"
    end

    it "should be updated if new primary is saved" do
      @contact.contact_attributes << NewTelephone.new(
        :account => @contact.owner,
        :category => :home,
        :value => "11235813",
        :primary => true
      )
      @contact.primary_attribute(@account, 'NewTelephone').value.should == "11235813"
    end
  end
end
