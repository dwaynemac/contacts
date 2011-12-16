class V0::AvatarsController < V0::ApplicationController
  def create
    contact = Contact.find(params[:contact_id])
    contact.avatar = params[:avatar][:file]
    if contact.save
      render :json => "OK", :status => :created
    else
      render :json => {:message => "Sorry, avatar not created", :errors => contact.errors}.to_json, :status => 400
    end
  end

  def destroy
    contact = Contact.find(params[:contact_id])

    # contact.remove_avatar! not working
    contact.remove_avatar = true
    contact.save!
    
    render :json => "OK"
  end
end
