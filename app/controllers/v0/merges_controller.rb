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
  # == Response code
  #
  #   - if merge was successfull satus is 201
  #   - if merge was created but needs admin confirmation is 202
  #   - if merge couldn't be created is 400
  #   - if contacts dont exist 404
  #
  def create

    # LogicalModel fix. until LogicalModel supports read-only attributes this is needed.
    params[:merge].delete(:state)

    @merge = Merge.new(params[:merge])
    authorize! :create, @merge

    if @merge.save
      @merge.start
      if @merge.merged? || @merge.merging? || @merge.pending?
        render json: {id: @merge.id }, status: 201
      else # pending_confirmation
        render json: {id: @merge.id}, status: 202
      end
    else
      render json: {
          message: "",
          error_codes: [],
          errors: @merge.errors.messages
      }, status: 400
    end
  end

end
