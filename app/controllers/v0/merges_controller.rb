# @restful_api v0
class V0::MergesController < V0::ApplicationController
  load_and_authorize_resource except: [:create]

  ##
  # Gets merge
  #
  # @url /v0/merges/:id
  # @action GET
  #
  # @required [String] id merge id
  #
  # @response [Merge]
  def show
    render json: @merge
  end

  ##
  # Creates and starts merge
  #
  # @url /v0/merges
  # @action POST
  #
  # @required [Hash] merge  merge attributes
  # @required [String] account_name  current account_name
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

        post_to_activity_stream

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

  private

  def post_to_activity_stream
    entry = ActivityStream::Activity.new(
        target_id: @merge.father._id, target_type: 'Contact',
        object_id: @merge.son._id, object_type: 'Contact',
        generator: 'contacts',
        verb: 'merged',
        content: "#{params[:username]} merged #{@merge.son.full_name} into #{@merge.father.full_name}",
        public: true,
        username: params[:username] || 'system',
        account_name: params[:account_name] || 'system',
        created_at: @merge.created_at.to_s,
        updated_at: @merge.updated_at.to_s
    )
    res = entry.create(username:  params[:username], account_name: params[:account_name])
    1+1
    1+1
  end

end
