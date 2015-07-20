class V0::AddressesController < V0::ApplicationController
  
  authorize_resource

  ##
  # Returns list of occupations in JSON
  #
  # @url /v0/addresses
  # @action GET
  #
  # @optional [String] status only contacts with choosen status
  # @optional [Bool] only_with_occupation only contacts wich have an occupation
  #
  # @response_field [Hash] A tree of adresses
  #     Example: {
  #       Argentina: {
  #         Capital Federal: {
  #           Capital Federal: {
  #             Belgrano: {},
  #             Palermo : {}
  #           }
  #         },
  #         Córdoba : {
  #           Villa Carlos Paz: {
  #             Manantiales: {}
  #           }
  #         }
  #       },
  #       France: {}
  #     }
 
  def index
    query = {}

    if !params[:status].nil?
      query[:status] = params[:status]
    end

    if params[:only_with_occupation] == "true"
      query['$and'] = [
        {"contact_attributes._type" => "Occupation"},
        {"contact_attributes._type" => "Address"} 
      ]
    else
      query["contact_attributes._type"] = "Address" 
    end

    addresses = {}
    Contact.where(query).each do |contact|
      contact.addresses.each do |add|
        addresses = create_address_tree(add, addresses, "country")
      end
    end
    
    render :json => {:addresses => addresses}.to_json, :status => 200
  end

  private

  ADDRESS_KEY_TABLE = {
    "country" => "state",
    "state" => "city",
    "city" => "neighborhood"
  }

  def create_address_tree (address, tree, node)
    return {} if node.nil? || address.send(node).blank?

    if tree[address.send(node)].nil?
      next_branch = {}     
    else
      next_branch = tree[address.send(node)]
    end
    
    tree[address.send(node)] = create_address_tree( address,
                                                    next_branch,
                                                    ADDRESS_KEY_TABLE[node])
    return tree
  end

end
