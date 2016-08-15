# @restful_api v0
class V0::MailchimpSynchronizersController < V0::ApplicationController
  rescue_from Gibbon::MailChimpError, with: :mailchimp_error
  authorize_resource

  before_filter :get_account

  # @url /v0/mailchimp_synchronizers/:id/synchronize
  # @action POST
  #
  # @required id
  def synchronize
    synchro = MailchimpSynchronizer.find(params[:id])
    if !synchro.nil?
      synchro.queue_subscribe_contacts
      render json: "OK", status: 202
    else
      render json: 'Synchronizer missing', status: 404
    end
  end

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
      synchro.update_sync_options(params[:synchronizer])
      synchro.queue_subscribe_contacts
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

  ##
  # Gets scope for given synchronizer
  # @url /v0/mailchimp_synchronizer/get_scope/:id
  # @action GET
  #
  # @required [String] synchronizer[api_key] Mailchimp API KEY
  #
  def get_scope
    ms = MailchimpSynchronizer.where(api_key: params[:api_key]).first
    segments = params[:mailchimp_list][:mailchimp_segments_attributes] if params[:filter_method] == "segments"
    
    render json: ms.calculate_scope_count(params[:filter_method], segments)
  end

  protected

    def mailchimp_error(exception)
      message = 
      case exception.message
      when /Invalid MailChimp List ID/
        t('errors.mailchimp.list_not_found')
      else
        exception.message
      end
      render json: message, status: 500
      return
    end

end
