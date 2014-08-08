# @restful_api v0
class V0::MailchimpSegmentController < V0::ApplicationController

  before_filter :get_account

  ##
  # Creates a Mailchimp Segment.
  # @url /v0/mailchimp_segments
  # @action POST
  #
  # @required [String segment[api_key] Mailchimp API KEY
  # @optional [Array] segment[statuses] Array of statuses (Strings)
  #   Possible values = student, prospect, former_student
  # @optional [Array] segment[coefficients] Array of coefficients
  #   Possible values = fp, perfil, pmas
  # @optional [String] segment[gender] Gender
  #   Possible values = male, female
  # @required [String] account_name
  #
  # @response_field [String] OK message
  # @response_field [String] Segment ID
  #
  def create
    synchro = MailchimpSynchronizer.where(api_key: params[:segment][:api_key]).first

    if !synchro.nil?
      segment = MailchimpSegment.new(
        mailchimp_synchronizer: synchro,
        statuses: params[:segment][:statuses],
        coefficients: params[:segment][:coefficients],
        gender: params[:segment][:gender]
      )

      if segment.save
        render json: {message: "OK", id: segment.id}.to_json,
          status: 201
      else
        render json: {message: "Sorry, The segment could not be created"}.to_json,
          status: 400
      end
    else
      render json: {message: "Synchronizer missing"}.to_json, status: 400
    end
  end

  ##
  # Destroys given Segment
  # @url /v0/mailchimp_segment/:id
  # @action DELETE
  #
  # @required [String] segment[api_key] Mailchimp API KEY
  #
  def destroy
    @synchro = MailchimpSynchronizer.where(api_key: params[:synchronizer][:api_key]).first
    if !@synchro.nil?
      if @synchro.status.to_sym != :working
        MailchimpSegment.find(params[:id]).destroy
        render json: 'destroyed', status: 200
      else
        render json: "Synchronizer is currently working, wait for it to finish before deletion of segments.",
          status: 409
      end
    else
      render json: 'Synchronizer missing', status: 400
    end
  end

end
