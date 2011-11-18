class V0::ContactAttributesController < V0::ApplicationController

  before_filter :set_scope

  #  Updates specified values of a contact attribute
  #
  #  == Request:
  #   PUT /v0/contact_attributes/:id/
  #   PUT /v0/accounts/:account_name/contacts/:id
  #
  #  == Valid params:
  #   :account_name [string]: (account name) scopes account
  #   :contact_id [string]: (account name) change de account the contact belongs to
  #   :id
  #   :contact_attribute
  #     :category [string]: change the name of the category
  #     :value [string]: change the value of the contact attribute
  #
  #  == Response:
  #   :response [string] = "OK" if success or error message
  #   :status [integer] = type of error
  def update
    @contact_attribute = @scope.find(params[:id])

    if @contact_attribute.update_attributes(params[:contact_attribute])
      render :json => "OK"# , :status => :updated
    else
      render :json => { :message => "Sorry, contact attribute not updated",
       :error_codes => [],
       :errors => @contact_attribute.errors }.to_json, :status => 400
    end
  end

  private

  #  Sets the scope
  def set_scope
    case action_name.to_sym
      when :index, :update, :create
        if @account
          @scope = @account.lists.first.contacts
        else
          @scope = ContactAttribute
        end

      when :destroy
        @scope = ContactAttribute
      else
        @scope = ContactAttribute
    end
  end

end
