shared_examples_for "Secure API Controller"  do
  describe "#index" do
    before(:each) do
      get :index
    end
    it "should deny access without app_key" do
      should respond_with(401)
    end
  end

  describe "#show" do
    before do
      get :show, :id => 1
    end
    it "should deny access without app_key" do
      should respond_with(401)
    end
  end

  describe "#create" do
    before do
      post :create
    end
    it "should deny access without app_key" do
      should respond_with(401)
    end
  end

  describe "#update" do
    before do
      post :update, :id => 1
    end
    it "should deny access without app_key" do
      should respond_with(401)
    end
  end

  describe "#destroy" do
    before do
      post :destroy, :method => :delete, :id => 1
    end
    it "should deny access without app_key" do
      should respond_with(401)
    end
  end
end