class V0::OccupationsController < V0::ApplicationController
  
  authorize_resource

  ##
  # Returns list of occupations in JSON
  #
  # @url /v0/occupations
  # @action GET
  #
  # @optional [String] status only contacts with choosen status
  # @optional [Bool] only_with_address only contacts wich have an address
  #
  # @response_field [Array <String>] occupations
 
  def index
    query = {}

    if !params[:status].nil?
      query[:status] = params[:status]
    end

    if params[:only_with_address] == "true"
      query['$and'] = [
        {"contact_attributes._type" => "Occupation"},
        {"contact_attributes._type" => "Address"} 
      ]
    else
      query["contact_attributes._type"] = "Occupation"
    end

    occupations = []
    Contact.where(query).each do |contact|
      occupations = occupations | contact.occupations.map {|occ| occ.value}
    end
    
    render :json => {:occupations => occupations}.to_json, :status => 200
  end

end
