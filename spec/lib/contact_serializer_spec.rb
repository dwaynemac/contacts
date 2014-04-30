require 'spec_helper'

describe ContactSerializer do

  let(:serializer){ContactSerializer.new(mode: mode, contact: contact)}
  let(:serialized_keys){serializer.serialize.keys}
  let(:contact){Contact.make()}

  describe "with mode: 'all'" do
    let(:mode){ 'all' }
  end
  describe "with mode: 'select'" do
    let(:mode){ 'select' }
    describe "with select: [:avatar]" do
      before do
        #given that contact has an avatar
        contact.avatar = File.open('spec/support/ghibli_main_logo.gif')

        #select avatar
        serializer.select = [:avatar] 
      end
      describe "#serialize" do
        it "includes :avatar" do
          binding.pry
          ( :avatar ).should be_in serialized_keys
        end
      end
    end
  end

  describe "with mode: 'only_name'" do
    let(:mode){ 'only_name' }
    describe "#serialize" do
      it "returns :id, :name" do
        serialized_keys.should == [:id, :name]
      end
    end
  end

end
