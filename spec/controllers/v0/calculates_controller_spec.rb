# encoding: utf-8
require 'spec_helper'


describe V0::CalculatesController do

  describe "#average_age" do
    # age calculation specs are in Calculation::Age specs

    def do_request(params={})
      get :average_age, params.merge(app_key: V0::ApplicationController::APP_KEY)
    end

    describe "without ref_date" do
      describe "can scope to account_students" do
        before do
          Contact.make(estimated_age: 17)
          do_request
        end
        it { should respond_with 200 }
        it "returns average age" do
          JSON.parse(response.body).should == { 'result' => 17.0 }
        end
      end
    end
  end
end
