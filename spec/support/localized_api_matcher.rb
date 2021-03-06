shared_examples_for 'Localized API' do
  describe "#index" do
    before do
      Rails.cache.clear
      PadmaAccount.stub(:find).and_return(PadmaAccount.new(name: 'cervino', timezone: 'Brasilia'))
    end
    context "with account_name" do
      before do
        get :index, account_name: 'cervino', :app_key => V0::ApplicationController::APP_KEY
      end
      it "should set timezone" do
        Time.zone.to_s.should == '(GMT-03:00) Brasilia'
      end
    end
  end
  describe "#create" do
    before do
      Rails.cache.clear
      PadmaAccount.stub(:find).and_return(PadmaAccount.new(name: 'cervino', timezone: 'Buenos Aires'))
    end
    context "with account_name" do
      before { post :create,
                    account_name: 'cervino',
                    contact: {},
                    app_key: V0::ApplicationController::APP_KEY }
      it "should set timezone" do
        Time.zone.to_s.should == '(GMT-03:00) Buenos Aires'
      end
    end
  end
end