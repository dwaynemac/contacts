class ContactAttribute
  include Mongoid::Document
  #include Mongoid::Timestamps

  field :public, type: Boolean
  field :value, type: String

  validates :value, :presence => true, :unless => proc {self.is_a? Address}

  validate :write_enabled

  embedded_in :contact

  referenced_in :account

  before_create :assign_owner

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

      # remove repeated telephones
      value_counts = self.any_of({account_id: account.id},{public: true},{_type: "Telephone"}).only(:value).aggregate
      repeated_values = value_counts.map{|k,v| k if v>1}
      attrs_without_repetition = attrs.reject{|a| a.is_a?(Telephone) && a.value.in?(repeated_values) && a.account_id!=account.id}

      # mask non-public phones not belonging to given account
      attrs_without_repetition.map do |a|
        if a.is_a?(Telephone) && !a.public? && a.account_id!=account.id
          a.value = a.masked_value
          a.readonly!
          a
        else
          a
        end
      end
    else
      any_of({account_id: account.id}, { public: true})
    end
  end

  # TODO refactor readonly functionality to a Module and include it here
  def readonly!
    @readonly = true
  end

  def readonly?
    @readonly
  end

  protected

  def assign_owner
    self.account = contact.owner if self.account.blank? && contact.owner.present?
  end

  def write_enabled
    raise "ReadOnly" if @readonly
  end
end
