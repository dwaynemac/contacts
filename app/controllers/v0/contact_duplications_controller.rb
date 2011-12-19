class V0::ContactDuplicationsController < V0::ApplicationController
  def index
    if params[:contact_id].present?
      @contact = Contact.find(params[:contact_id])
    else
      @contact = Contact.new(params[:contact])
    end

    @contacts = @contact.similar
  end
end
