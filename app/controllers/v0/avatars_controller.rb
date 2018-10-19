# @restful_api v0
class V0::AvatarsController < V0::ApplicationController

  ##
  # Sets contact avatar overriding if there is already one
  # @url /v0/contacts/:contact_id/avatar
  # @url /v0/avatar
  # @action POST
  # @optional [String] contact_id
  # @required [Avatar] avatar
  # @optional [String] kshema_id
  # @response_code 201
  # @example_response == Code: 201
  #   "OK"
  # @response_code 400
  # @example_response == Code: 400
  #   {message: 'Sorry', errors: [...]}
  def create
    authorize! :create, :avatar
    if params.has_key?(:kshema_id)
      contact = Contact.where(kshema_id: params[:kshema_id]).first
    else
      contact = Contact.find(params[:contact_id])
    end
    contact.avatar = params[:avatar][:file]
    contact.check_duplicates = false
    if contact.save validate: false
      render :json => "OK", :status => :created
    else
      render :json => {:message => "Sorry, avatar not created", :errors => contact.errors}.to_json, :status => 400
    end
  end

  ##
  # Updates avatar
  # update action is required to manipulate image
  # that action must be reflected as a method in avatar_uploader.rb
  # @url /v0/contacts/:contact_id/avatar
  # @action PATCH
  # @required[String] contact_id
  # @required[String] update_action
  # @response_code 201
  
  def update
    authorize! :update, :avatar
    contact = Contact.find(params[:contact_id])
    
    case params[:update_action]
    when "rotate"
      contact.avatar.rotate
    end

    if contact.save validate: false
      render :json => "OK"
    else
      render :json => { 
        :message => "Sorry, avatar could not be updated",
        :errors => contact.errors
      }.to_json, :status => 400
    end
  end

  ##
  # Removes contact's avatar
  #
  # @url /v0/contacts/:contact_id/avatar
  # @action DELETE
  # @required [String] contact_id
  # @example_response "OK"
  def destroy
    authorize! :destroy, :avatar
    contact = Contact.find(params[:contact_id])

    # contact.remove_avatar! not working
    contact.remove_avatar = true
    contact.save!
    
    render :json => "OK"
  end
end
