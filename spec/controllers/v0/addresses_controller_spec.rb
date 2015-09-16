require 'spec_helper'

describe V0::AddressesController do

  describe "#index" do
    before do
      coghlan_address = Address.new( :country => "Argentina",
                                      :city => "Capital Federal",
                                      :state => "Capital Federal",
                                      :neighborhood => "Coghlan",
                                      :value => "fake"
                                    )

      palermo_address = Address.new(:country => "Argentina",
                                    :state => "Capital Federal",
                                    :city => "Capital Federal",
                                    :neighborhood => "Palermo",
                                    :value => "fake"
                                   )

      cordoba_address = Address.new(:country => "Argentina",
                                    :state => "Cordoba",
                                    :city => "Villa Carlos Paz",
                                    :neighborhood => "Manantiales",
                                    :value => "fake"
                                   )

      france_address = Address.new( :country => "France",
                                    :value => "fake"
                                  )

      lawyer_occupation = Occupation.new(:value => "Lawyer")

      @contact_from_coghlan = Contact.make
      @contact_from_coghlan.contact_attributes << coghlan_address
      
      @contact_from_palermo = Contact.make(:status => "student")
      @contact_from_palermo.contact_attributes << palermo_address
      @another_contact_from_palermo = Contact.make(:status => "student")
      @another_contact_from_palermo.contact_attributes << palermo_address

      @contact_from_cordoba = Contact.make(:status => "student")
      @contact_from_cordoba.contact_attributes << cordoba_address
      @contact_from_cordoba.contact_attributes << lawyer_occupation 

      @contact_from_france = Contact.make(:status => "student")
      @contact_from_france.contact_attributes << france_address
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

        it "gets all the addresses (but not repeated)" do
          json = JSON.parse(response.body)

          json["addresses"]["Argentina"].should_not be_nil
          argentina = json["addresses"]["Argentina"]
          
          argentina["Capital Federal"].should_not be_nil 
          capital_federal = argentina["Capital Federal"]
          capital_federal["Capital Federal"].should_not be_nil
          capital_federal = capital_federal["Capital Federal"]
          
          capital_federal["Coghlan"].should_not be_nil
          capital_federal["Palermo"].should_not be_nil

          argentina["Cordoba"].should_not be_nil
          cordoba = argentina["Cordoba"]
          cordoba["Villa Carlos Paz"]["Manantiales"].should_not be_nil
          
          json["addresses"]["France"].should_not be_nil
        end
      end

      describe "filter by status" do
        before do
          get :index, {:app_key => V0::ApplicationController::APP_KEY,
                       :status => "student"}
        end

        it {should respond_with (200)}

        it "gets all the addresses from students (but not repeated)" do
          json = JSON.parse(response.body)

          json["addresses"]["Argentina"].should_not be_nil
          argentina = json["addresses"]["Argentina"]
          
          argentina["Capital Federal"].should_not be_nil 
          capital_federal = argentina["Capital Federal"]
          capital_federal["Capital Federal"].should_not be_nil
          capital_federal = capital_federal["Capital Federal"]
          
          # Coghlan should be nil
          capital_federal["Coghlan"].should be_nil
          capital_federal["Palermo"].should_not be_nil

          argentina["Cordoba"].should_not be_nil
          cordoba = argentina["Cordoba"]
          cordoba["Villa Carlos Paz"]["Manantiales"].should_not be_nil
          
          json["addresses"]["France"].should_not be_nil

        end
      end

      describe "filter by status and occupation" do
        before do
          get :index, {:app_key => V0::ApplicationController::APP_KEY,
                       :status => "student",
                       :only_with_occupation => "true"}
        end

        it {should respond_with (200)}

        it "gets all the addresses form students with occupations" do
          json = JSON.parse(response.body)

          json["addresses"]["Argentina"].should_not be_nil
          argentina = json["addresses"]["Argentina"]
          
          #Capital Federal should be nil
          argentina["Capital Federal"].should be_nil 

          argentina["Cordoba"].should_not be_nil
          cordoba = argentina["Cordoba"]
          cordoba["Villa Carlos Paz"]["Manantiales"].should_not be_nil
          
          #France should be nil
          json["addresses"]["France"].should be_nil
        end
      end
    end
  end
end
