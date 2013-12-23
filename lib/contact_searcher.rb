##
# ContactSearcher converts a simple Hash that can be sent through API 
# into mongo query.
#
class ContactSearcher

  attr_accessor :initial_scope
  attr_accessor :account_id
  attr_accessor :new_selector

  # @param scope [Mongoid::Criteria]
  # @param acc_id [String] account_id
  def initialize(scope=Contact, acc_id=nil)
    self.initial_scope = scope
    self.account_id = acc_id
  end

  # This is same as #where but will make some transformations on selector.
  #
  # first_name and last_name are converted to Regex
  #
  # @param selector   [ Hash ]      query
  #
  # @option selector :telephone, searches within all telephones
  # @option selector :email, searches within all emails
  # @option selector :address
  # @option selector :custom_attribute
  # @option selector :local_status      only considered if account_id is specified
  # @option selector :local_teacher      only considered if account_id is specified
  # @option selector :attribute_value_at [Hash] keys: attribute, value, ref_date
  #
  # @return [Mongoid::Criteria]
  def api_where(selector=nil)
    return self.initial_scope if selector.nil?

    self.new_selector = {'$and' => []}

    selector.each do |k,v|
      unless v.blank?
        case k.to_s
          when 'telephone', 'email', 'address', 'custom_attribute'
            andit({
              :contact_attributes => { '$elemMatch' => { "_type" => k.to_s.camelize, "value" => Regexp.new(v.to_s,Regexp::IGNORECASE)}}
            })
          when 'country', 'state', 'city', 'postal_code'
            andit({:contact_attributes => { '$elemMatch' => { "_type" => "Address", k => Regexp.new(v.to_s)}}})
          when 'contact_attributes'
            andit({k => v})
          when 'date_attributes'
            v.each do |sv|
              aux = DateAttribute.convert_selector(sv)
              andit(aux) unless aux.nil?
            end
          when 'date_attribute'
            aux = DateAttribute.convert_selector(v)
            andit(aux) unless aux.nil?
          when 'local_status', 'coefficient', 'local_teacher'
            if account_id.present?
              andit({
                  :local_unique_attributes => {'$elemMatch' => {_type: k.to_s.camelcase,
                                                                value: {'$in' => v.to_a},
                                                                account_id: account_id}}
              })
            end
          when 'level' # convert level name to level number
            if v.is_a? Array
              andit({:level => { '$in' => v.map {|lvl| Contact::VALID_LEVELS[lvl]} }})
            else
              andit({:level => Contact::VALID_LEVELS[v]})
            end
          when /^(.+)_for_([^=]+)$/
            local_attribute = $1
            a = get_account($2)
            if a
              andit({
                :local_unique_attributes => {'$elemMatch' => {_type: local_attribute.to_s.camelcase, value: {'$in' => v.to_a}, account_id: a.id}}
              })
            end
          when 'first_name', 'last_name'
            self.new_selector[k] = v.is_a?(String)? Regexp.new(v,Regexp::IGNORECASE) : v
          when 'updated_at'
            andit({:updated_at => { '$gt' => v }})
          else
            self.new_selector[k] = v
        end
      end
    end

    clean_selector

    self.initial_scope.where(self.new_selector)
  end

  private

  def andit(hsh)
    self.new_selector['$and'] << hsh
  end

  def clean_selector
    if self.new_selector['$and'].empty?
      self.new_selector.delete('$and')
    elsif self.new_selector['$and'].size == 1
      aux = self.new_selector.delete('$and')[0]
      self.new_selector = self.new_selector.merge(aux)
    end
  end

  # Will search for account with given name and cache it
  # or read it from cache of sucesive calls
  # @param account_name [String]
  def get_account(account_name)
    sanitized_account_name = account_name.gsub('.', '_')

    if (a = instance_variable_get("@cached_account_#{sanitized_account_name}")).blank?
      a = Account.where(name: account_name).first
      instance_variable_set("@cached_account_#{sanitized_account_name}", a)
    end

    a
  end
  
end
