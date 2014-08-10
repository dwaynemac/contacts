# @restful_api v0
class V0::MailchimpSynchronizersController < V0::ApplicationController

  before_filter :get_account

  ##
  # Creates a Mailchimp Contact Synchronizer.
  # @url /v0/mailchimp_synchronizers
  # @action POST
  #
  # @required [String] synchronizer[api_key] Mailchimp API KEY
  # @required [String] account_name
  #
  # @response_field [String] OK message
  #
  def create
    synchro = MailchimpSynchronizer.new(
      account: @account,
      api_key: params[:synchronizer][:api_key]
    )

    if synchro.save
      render json: {message: "OK", id: synchro.id}.to_json,
        status: 201
    else
      render json: {message: "Sorry, The synchronizer could not be created"}.to_json,
        status: 400
    end
  end
  
  def update
    synchro = MailchimpSynchronizer.find(params[:id])
    if !synchro.nil?
      synchro.update_attributes(params[:synchronizer])
      synchro.update_fields_in_mailchimp   
      render json: "OK", status: 200
    else
      render json: 'Synchronizer missing', status: 400
    end
  end

  ##
  # Destroys given Synchronizer
  # @url /v0/mailchimp_synchronizer/:id
  # @action DELETE
  #
  # @required [String] synchronizer[api_key] Mailchimp API KEY
  #
  def destroy
    @synchro = MailchimpSynchronizer.where(api_key: params[:synchronizer][:api_key]).first
    if !@synchro.nil?
      if @synchro.status.to_sym != :working
        @synchro.destroy
        render json: 'destroyed', status: 200
      else
        render json: "Synchronizer is currently working, wait for it to finish before deletion.",
          status: 409
      end
    else
      render json: 'Synchronizer missing', status: 400
    end
  end

end
