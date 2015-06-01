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

  LOCAL_ATTRIBUTE_META_ACCESSOR_REGEX = /^(.+)_for_([^=]+)$/
  CUSTOM_ATTRIBUTE_META_ACCESSOR_REGEX = /^custom_(.+)$/

  # This is same as #where but will make some transformations on selector.
  #
  # first_name and last_name are converted to Regex
  #
  # @param selector   [ Hash ]      query
  #
  # @option selector :nucleo_unit_id, scopes to accounts with given nucleo_id
  # @option selector :telephone, searches within all telephones
  # @option selector :email, searches within all emails
  # @option selector :address
  # @option selector :custom_attribute
  # @option selector :local_status      only considered if account_id is specified
  # @option selector :local_teacher     only considered if account_id is specified
  # @option selector :last_seen_at      only considered if account_id is specified
  # @option selector :attribute_value_at [Hash] keys: attribute, value, ref_date
  #
  # @return [Mongoid::Criteria]
  def api_where(selector=nil)
    return self.initial_scope if selector.nil?

    self.new_selector = {'$and' => []}
    selector.each do |k,v|
      unless v.blank?
        k = k.to_s
        case k
          when 'nucleo_unit_id'
            account = PadmaAccount.find_by_nucleo_id(v)
            if account
              local_account = get_account(account.name)
              andit({
                account_ids: local_account.id
              })
            else
              # Mongo Queries can get slow. If account doesnt exist avoid querying.
              raise Exceptions::ForceEmptyQuery
            end
          when 'telephone', 'email', 'address', 'custom_attribute', 'occupation'
            andit({
              :contact_attributes => { '$elemMatch' => { "_type" => k.camelize, "value" => Regexp.new(v.to_s,Regexp::IGNORECASE)}}
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
              if k == 'coefficient'
                filter_by_coefficient v, account_id
              else
                andit({
                    :local_unique_attributes => {'$elemMatch' => {_type: k.camelcase,
                                                                  value: {'$in' => v.to_a},
                                                                  account_id: account_id}}
                })
              end
            end
          when 'level' # convert level name to level number
            if v.is_a? Array
              # ignore filter if all levels are considered
              unless v.select{|lvl| lvl != ''}.size == Contact::VALID_LEVELS.size
                andit({:level => { '$in' => v.map {|lvl| Contact::VALID_LEVELS[lvl]} }})
              end
            else
              andit({:level => Contact::VALID_LEVELS[v]})
            end
          when LOCAL_ATTRIBUTE_META_ACCESSOR_REGEX
            local_attribute = $1
            a = get_account($2)
            if a
              if local_attribute.to_s == 'coefficient'
                filter_by_coefficient v, a.id
              else
                andit({
                  :local_unique_attributes => {'$elemMatch' => {_type: local_attribute.to_s.camelcase, value: {'$in' => v.to_a}, account_id: a.id}}
                })
              end
            end
          when 'first_name', 'last_name'
            self.new_selector[k] = v.is_a?(String)? Regexp.new(v,Regexp::IGNORECASE) : v
          when 'tags'
            cs = Tag.find(v).map(&:contact_ids).flatten.uniq
            andit({
              :_id => {'$in' => cs}
            })
          when 'updated_at'
            andit({:updated_at => { '$gt' => v }})
          when 'last_seen_at'
            if account_id.present?

              andit({:local_unique_attributes => {'$elemMatch' => {_type: "LastSeenAt",
                                                                value: {'$lt' => DateTime.parse(v).to_time_in_current_zone.utc},
                                                                account_id: account_id}}
              })
            end
          when CUSTOM_ATTRIBUTE_META_ACCESSOR_REGEX
            custom_attribute_key = $1
            if account_id.present?
              andit({
                :contact_attributes => { '$elemMatch' => { 
                                            _type: "CustomAttribute", 
                                            key: custom_attribute_key,
                                            value: Regexp.new(v.to_s,Regexp::IGNORECASE),
                                            account_id: account_id
                                      }}
              })
            end
          else
            self.new_selector[k] = v
        end
      end
    end
    clean_selector

    self.initial_scope.where(self.new_selector)
  rescue Exceptions::ForceEmptyQuery
    Contact.where(id: 'force-empty-query') # force an empty result
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
    sanitized_account_name = account_name.gsub(/\.|-/, '_')

    if (a = instance_variable_get("@cached_account_#{sanitized_account_name}")).blank?
      a = Account.where(name: account_name).first
      instance_variable_set("@cached_account_#{sanitized_account_name}", a)
    end

    a
  end

  def filter_by_coefficient(value,account_id)
    unless value.is_a?(Array) && value.select{|coef| coef != ''}.size == Coefficient::VALID_VALUES.size
      andit({
          :local_unique_attributes => {'$elemMatch' => {_type: 'Coefficient',
                                                        value: {'$in' => value.to_a},
                                                        account_id: account_id}}
      })
    end
  end
  
end
