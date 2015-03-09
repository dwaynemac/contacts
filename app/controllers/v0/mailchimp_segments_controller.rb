# @restful_api v0
class V0::MailchimpSegmentsController < V0::ApplicationController

  authorize_resource

  before_filter :get_account, except: :destroy

  ##
  # Creates a Mailchimp Segment.
  # @url /v0/mailchimp_segments
  # @action POST
  #
  # @required [String] synchronizer[id] Mailchimp API KEY
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
    synchro = MailchimpSynchronizer.find(params[:synchronizer][:id])

    if !synchro.nil?
      segment = MailchimpSegment.new(
        mailchimp_synchronizer: synchro,
        statuses: params[:segment][:statuses],
        coefficients: params[:segment][:coefficients],
        gender: params[:segment][:gender],
        name: params[:segment][:name]
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
  # @required [String] id Segment id
  #
  def destroy
    segment = MailchimpSegment.find(params[:id])
    if !segment.nil?
      synchro = segment.mailchimp_synchronizer
      if synchro.status.to_sym != :working
        segment.destroy
        render json: 'destroyed', status: 200
      else
        render json: "Synchronizer is currently working, wait for it to finish before deletion of segments.",
          status: 409
      end
    else
      render json: 'Segment missing', status: 400
    end
  end

end
