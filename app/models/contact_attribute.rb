class ContactAttribute
  include Mongoid::Document
  include ReadOnly

  field :public, type: Boolean
  field :value, type: String

  validates :value, :presence => true

  embedded_in :contact

  referenced_in :account

  before_save :assign_owner

  # @param options [Hash]
  def as_json(options={})
    if options.nil?
      # avoid exception in case it was called with nil
      options = {}
    elsif options[:methods].present?
      # :_type is excluded from json by default by Mongoid
      options[:methods] += [:_type, :contact_id]
    end

    super({:methods => [:_type, :contact_id]}.merge(options))
  end

  # Returns ContactAttributes visible to account
  #
  # IF :include_masked is used then it can't be further chained as it will return an Array
  #
  # @param [Account] account
  # @param [Hash] options
  # @option [TrueClass] include_masked
  #
  # if :include_masked is used
  #    @return [Array]
  # else
  #    @return [Criteria]
  def self.for_account(account, options = {})
    if options[:include_masked]

      # get attributes
      attrs = self.any_of({account_id: account.id},{public: true},{_type: "Telephone"})

      # remove repeated telephones keeping owned version
      value_counts = self.any_of({account_id: account.id},{public: true},{_type: "Telephone"}).only(:value).aggregate
      repeated_values = value_counts.map{|k,v| k if v>1}
      attrs_without_repetition = attrs.reject{|a| a.is_a?(Telephone) && a.value.in?(repeated_values) && a.account_id!=account.id}

      # mask non-public phones not belonging to given account
      attrs_without_repetition.map do |a|
        if a.is_a?(Telephone) && !a.public? && a.account_id!=account.id
          a.mask_value!
        else
          a
        end
      end
    else
      any_of({account_id: account.id}, { public: true})
    end
  end

  def mask_value!
    self.value = self.masked_value
    self.readonly!
    self
  end

  protected

  def assign_owner
    self.account = self.contact.owner if self.account.blank? && self.contact.owner.present?
  end


  def contact_id
    contact.id
  end
end
