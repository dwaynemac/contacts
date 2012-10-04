class V0::MergesController < V0::ApplicationController
  load_and_authorize_resource except: [:create]

  ##
  # Gets merge
  #
  # @url [GET] /v0/merges/:id
  #
  # @argument id [String] merge id
  #
  # @example_response { id: '4trd3f1e', state: 'ready', ... }
  def show
    render json: @merge
  end

  ##
  # Creates and starts merge
  #
  # @url [POST] /v0/merges
  #
  # @argument merge [Hash] merge attributes
  # @argument account_name [String] current account_name
  #
  # @key_for merge first_contact_id [String] a contact id
  # @key_for merge second_contact_id [String] a contact id
  #
  # @example_response { id: '4trd3f1e' }
  #
  # @response_field id [String] id of created Merge
  #
  def create

    @merge = Merge.new(params[:merge])
    authorize! :create, @merge

    if @merge.save
      @merge.start
      render json: {id: @merge.id}, status: 202
    else
      render json: {
          message: "",
          error_codes: [],
          errors: @merge.errors.messages
      }, status: 400
    end
  end

end
