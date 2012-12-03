# @topic Avatar
# @url /v0/contacts/:contact_id/avatar
class V0::AvatarsController < V0::ApplicationController

  ##
  # Sets contact avatar overriding if there is already one
  # @url [POST] /v0/contacts/:contact_id/avatar
  # @argument contact_id [String]
  # @argument avatar [Hash]
  # @key_for avatar [File] file
  # @response_code 201
  # @example_response == Code: 201
  #   "OK"
  # @response_code 400
  # @example_response == Code: 400
  #   {message: 'Sorry', errors: [...]}
  def create

    contact = Contact.find(params[:contact_id])
    contact.avatar = params[:avatar][:file]
    contact.check_duplicates = false
    if contact.save!
      render :json => "OK", :status => :created
    else
      render :json => {:message => "Sorry, avatar not created", :errors => contact.errors}.to_json, :status => 400
    end
  end

  ##
  # Removes contact's avatar
  #
  # @url [DELETE] /v0/contacts/:contact_id/avatar
  # @argument contact_id [String]
  # @example_response "OK"
  def destroy
    contact = Contact.find(params[:contact_id])

    # contact.remove_avatar! not working
    contact.remove_avatar = true
    contact.save!
    
    render :json => "OK"
  end
end
