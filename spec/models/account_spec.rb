require File.dirname(__FILE__) + '/../spec_helper'

describe Account do

    it { should validate_presence_of :name }

    it { should reference_many :contacts }

    #it do
    #  Account.make
    #  should validate_uniqueness_of :name
    #end

    it "should validate existing PadmaAccount" do
        # spec_helper mocks PadmaAccount.find
        acc = Account.make_unsaved
        acc.should be_valid
    end

    it "not validate if it inexsistent PadmaAccount " do
        # mock ws interaction
        padma_account = PadmaAccount.new(:name => "mockedAccount")
        PadmaAccount.stub!(:find).and_return(nil)

        acc = Account.make_unsaved
        acc.should_not be_valid
    end
end