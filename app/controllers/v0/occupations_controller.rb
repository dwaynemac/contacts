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
    occupations_query = {
      :contact_attributes => {
        '$elemMatch' => {:_type => "Occupation"}
      }
    }

    if !params[:status].nil?
      query[:status] = params[:status]
    end

    if params[:only_with_address] == "true"
      query['$and'] = [
        occupations_query,
        {
          :contact_attributes => {
            '$elemMatch' => {:_type => "Address"}
          } 
        }
      ]
    else
      query[:contact_attributes] = occupations_query[:contact_attributes]
    end

    contacts = Contact.where(query)

    occupations = []
    contacts.each do |contact|
      occupations = occupations | contact.occupations.map {|occ| occ.value}
    end
    
    respond_to do |format|
      format.js {
        render :json => {:occupations => occupations}
      }
    end
  end

end
