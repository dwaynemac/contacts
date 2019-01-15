# encoding: UTF-8
require 'spec_helper'

describe V0::HistoryEntriesController do
  let!(:contact){ Contact.make }

  describe "#index" do
    let!(:match){ HistoryEntry.make(historiable_type: "Contact",
                                    historiable_id: contact.id)  }
    let!(:no_match){ HistoryEntry.make(historiable_type: "OtherClass",
                                       historiable_id: "other-id")  }
    before do
      get :index, app_key: V0::ApplicationController::APP_KEY,
          contact_id: contact.id
    end
    it { should respond_with 200 }
    it "should return history_entres of Contact" do
      expect(JSON.parse(response.body)["collection"].map{|h| h["_id"] }).to eq [match.id.to_s]
    end
  end
end
