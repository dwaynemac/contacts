require 'spec_helper'

describe Attachment do
  let(:contact){ Contact.make }
  let(:account){ Account.make }


  describe "when embbeded in a Contact" do
    let(:attachment){ Attachment.make(contact: contact) }

    describe "when saving" do
      before do
        extend ActionDispatch::TestProcess
        image = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
        contact.attachments << Attachment.new(file: image, name: "hello")
        contact.save!
      end
      it "should be saved in a specific folder" do
        contact.attachments.first.file.path.should include('uploads/attachment/file/')
      end
    end

    describe "#assign_owner" do
      describe "when #account.nil?" do
        it "sets attachment#account from contact#owner" do
          attachment.assign_owner
          attachment.account_id.should == contact.owner_id
        end
      end
      describe "when #account is already setted" do
        before do
          attachment.update_attribute :account_id, account.id
        end
        it "wont change attachment#account" do
          contact.owner_id.should_not == account.id
          attachment.account_id.should == account.id
          attachment.assign_owner
          attachment.account_id.should == account.id
        end
      end
    end
  end
  describe "when embbeded in a Import" do
    let(:import){ Import.make }
    let(:attachment){ Attachment.make(import: import) }

    describe "when saving" do
      before do
        extend ActionDispatch::TestProcess
        image = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
        import.attachment = Attachment.new(file: image, name: "hello")
        contact.save!
      end
      it "should be saved in a specific folder" do
        import.attachment.file.path.should include('uploads/attachment/file/')
      end
    end

    describe "#assign_owner" do
      describe "when #account.nil?" do
        it "sets attachment#account from import#account" do
          attachment.assign_owner
          attachment.account_id.should == import.account_id
        end
      end
      describe "when #account is already setted" do
        before do
          attachment.update_attribute :account_id, account.id
        end
        it "wont change attachment#account" do
          import.account_id.should_not == account.id
          attachment.account_id.should == account.id
          attachment.assign_owner
          attachment.account_id.should == account.id
        end
      end
    end
  end
end
