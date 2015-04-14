class CustomAttribute < ContactAttribute
  field :name
  field :key
  validate :name, :presence => true
  before_save :set_key

  def set_key
    self.key = self.name.gsub('-','_').parameterize('_') if self.name.present?
  end

  # @return [Array] custom keys that account uses

  def self.custom_keys_by_id(account_id)
    cond = {
      '$and' => [
        {contact_attributes: { '$elemMatch' => { _type: 'CustomAttribute'}}},
        {account_ids: account_id }
      ]
    }
    ret = nil

    if Contact.where(cond).count == 0
      ret = []
    else
      ActiveSupport::Notifications.instrument('map_reduce.get_keys') do
        collection = Contact.collection.map_reduce(map_js(account_id),reduce_js,query: cond, out: 'custom_keys')
        ret = collection.find().to_a
      end
      ActiveSupport::Notifications.instrument('map_name.get_keys') do
        ret.map!{|mr| mr['_id'] }
      end
    end

    ret
  end

  def self.custom_keys(account)
    CustomAttribute.custom_keys_by_id(account.id)
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
