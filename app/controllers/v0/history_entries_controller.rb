# @restful_api v0
class V0::HistoryEntriesController < V0::ApplicationController

  before_filter :get_contact

  # @url /v0/history_entries
  # @action POST
  # @required [HistoryEntry] history_entry
  def create
    @history_entry = @contact.history_entries.new(params[:history_entry])

    if @history_entry.save
      render :json => { :id => @history_entry.id}.to_json, :status => :created
    else
      render :json => { :message => "Sorry, history entry not created",
       :error_codes => [],
       :errors => @history_entry.errors }.to_json, :status => 400
    end
  end

  # @url /v0/history_entries/:id
  # @action DELETE
  # @required [String] id history entry id
  def destroy
    @scope = @contact.history_entries

    if params[:id] == "all"
      @scope.destroy_all
    else
      @scope.find(params[:id]).destroy
    end

    render :json => "OK"
  end

  private

  def get_contact
    @contact = Contact.find(params[:contact_id])
  end

end
