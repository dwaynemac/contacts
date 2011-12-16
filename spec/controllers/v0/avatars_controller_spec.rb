require 'spec_helper'

describe V0::AvatarsController do
  describe "#create" do
    context "if contact has no avatar" do
	    before(:each) do
	      @image = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
	      @contact = Contact.make(:avatar => nil)
	      post  :create,
		    :contact_id => @contact.id,
		    :avatar => {:file => @image},
		    :app_key => V0::ApplicationController::APP_KEY
	    end
	    it "should set given image as avatar of given contact" do
	      @contact.reload
	      @contact.avatar.should_not be_nil
	      @contact.avatar.url.should match /ghibli_main_logo\.gif/
	    end
    end
    context "if contact already has an avatar" do
      before do
	@image = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
	@contact = Contact.make(:avatar => @image)
	@new_image = fixture_file_upload('spec/support/robot3.jpg', 'image/jpg')
	post  :create,
	      :contact_id => @contact.id,
	      :avatar => {:file => @new_image},
	      :app_key => V0::ApplicationController::APP_KEY
	end
	it "should update the image as avatar" do
	  @contact.reload
	  @contact.avatar.should_not be_nil
	  @contact.avatar.url.should match /robot3\.jpg/
	end
    end
  end
  
  describe "#destroy" do
	before do
	  @image = fixture_file_upload('spec/support/ghibli_main_logo.gif', 'image/gif')
	  @contact = Contact.make(:avatar => @image)
	  delete  :destroy,
	        :contact_id => @contact.id,
	        :app_key => V0::ApplicationController::APP_KEY
	end
	it {should respond_with :success}
	it "should remove avatar" do
	  c = Contact.find(@contact.id)
	  c.avatar.should be_blank
	end
  end

  after(:each) do
    Contact.all.each(&:remove_avatar!)
  end
end
