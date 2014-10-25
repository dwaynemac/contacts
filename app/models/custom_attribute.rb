class CustomAttribute < ContactAttribute
  field :name

  validate :name, :presence => true

  # @return [Array] custom keys that account uses
  def self.custom_keys(account)
    cond = {
      '$and' => [
        {contact_attributes: { '$elemMatch' => { _type: 'CustomAttribute'}}},
        {account_ids: account.id }
      ]
    }
    ret = nil

    if Contact.where(cond).count == 0
      ret = []
    else
      ActiveSupport::Notifications.instrument('map_reduce.get_keys') do
        collection = Contact.collection.map_reduce(map_js(account.id),reduce_js,query: cond, out: 'custom_keys')
        ret = collection.find().to_a
      end
      ActiveSupport::Notifications.instrument('map_name.get_keys') do
        ret.map!{|mr| mr['_id'] }
      end
    end

    ret
  end

  private

  def self.map_js(account_id)
<<JS
function(){
  this.contact_attributes.forEach(function(ca){
    if (ca._type == 'CustomAttribute' && ca.account_id == '#{account_id}'){
      emit(ca.name,1);
    }
  });
}
JS
  end

  def self.reduce_js
<<JS
function(key,values){
  return key;
}
JS
  end
end
