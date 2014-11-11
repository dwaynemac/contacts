require 'spec_helper'

class ExampleClass
  include AccountNameAccessor

  attr_accessor :account_id

  def account
    Account.find(@account_id) if @account_id
  end

  def account=(new_account)
    @account_id = new_account.id
  end
end

describe AccountNameAccessor do
  let(:ec){ExampleClass.new}

  describe "when included" do
    it "adds account_name accessor to class" do
      expect(ec).to respond_to :account_name
    end
    it "adds account_name= setter to class" do
      expect(ec).to respond_to 'account_name='
    end
  end
end
