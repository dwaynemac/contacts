require 'spec_helper'

describe V0::OccupationsController do

  describe '#index' do
    before do
      address = Address.new(:country => "Argentina",
                            :city => "Capital Federal",
                            :state => "Capital Federal",
                            :value => "fake street"
                           )

      @lawyer = Contact.make      
      @lawyer.contact_attributes << Occupation.new(:value => "Lawyer")
      

      @doctor = Contact.make(:status => "student")      
      @doctor.contact_attributes << Occupation.new(:value => "Doctor")
      @another_doctor = Contact.make(:status => "student")      
      @another_doctor.contact_attributes << Occupation.new(:value => "Doctor")

      @fireman = Contact.make(:status => "student")     
      @fireman.contact_attributes << Occupation.new(:value => "Fireman")
      @fireman.contact_attributes << address
    end

    context "without app_key" do
      it "denys access" do
        get :index
        should respond_with(401)
      end
    end

    context "with app_key" do
      describe "without filters" do
        before do
          get :index, {:app_key => V0::ApplicationController::APP_KEY}
        end

        it {should respond_with (200)}

        it "gets all the occupations (but not repeated)" do
          json = JSON.parse(response.body)
          json["occupations"].size.should == 3
        end
      end

      describe "filter by status" do
        before do
          get :index, {:app_key => V0::ApplicationController::APP_KEY,
                       :status => "student"}
        end

        it {should respond_with (200)}

        it "gets all the occupations (but not repeated)" do
          json = JSON.parse(response.body)
          json["occupations"].size.should == 2
        end
      end

      describe "filter by status and address" do
        before do
          get :index, {:app_key => V0::ApplicationController::APP_KEY,
                       :status => "student",
                       :only_with_address => "true"}
        end

        it {should respond_with (200)}

        it "gets all the occupations (but not repeated)" do
          json = JSON.parse(response.body)
          json["occupations"].size.should == 1
        end
      end
    end
  end
end
