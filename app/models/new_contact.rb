class NewContact < ActiveRecord::Base
  
  VALID_STATUSES = [:student, :former_student, :prospect] # they are ordered by precedence (first has precedence)

  self.table_name = "contacts"
  has_objectid_primary_key

  has_many :account_contacts, foreign_key: :contact_id
  has_many :accounts, through: :account_contacts, foreign_key: :contact_id, class_name: "NewAccount"
  alias_method :linked_accounts, :accounts

  belongs_to :owner, class_name: "NewAccount"
		
  before_save :ensure_linked_to_owner
  attr_accessor :skip_assign_owner
  after_save :assign_owner, unless: :skip_assign_owner

  before_validation :set_status, unless: :skip_set_status
  
  validates_inclusion_of :status, in: VALID_STATUSES, allow_blank: true

  validates :first_name, presence: true

  attr_accessor :skip_set_status

  def local_statuses
  	self.account_contacts.collect(&:local_status)
  end

  def status
  	return self[:status].try(:to_sym)
  end

  def set_status
    distinct_statuses = local_statuses.compact.map(&:to_sym)
    # order of VALID_STATUSES is important
    VALID_STATUSES.each do |s|
      if distinct_statuses.include?(s)
        self.status = s
        break
      end
    end
  end

  # @return LocalUniqueAttribute.value 
  def local_value_for_account(attr_name,account_id)
    return self.account_contacts
               .where(account_id: account_id)
               .first
               .try
               .send('local_' + attr_name).to_sym
  end

  # @method xxx_for_yyy=(value)
  # @param value
  # Sets xxx local_unique_attribute on account_id yyy with value :value
  # @example
  #   Contact#coefficient_for_belgrano=Coefficient::PMENOS
  def method_missing(method_sym, *arguments, &block)
    # local_unique_attribute reader for an account_id
    
    if method_sym.to_s =~ /^(.+)_for_([^=]+)$/
      attr_name = $1
      account_name = $2
      sanitized_account_name = account_name.gsub('.', '_')
      #cache account to avoid multiple calls to accounts service
      if (a = instance_variable_get("@cached_account_#{sanitized_account_name}")).blank?
        a = NewAccount.where(name: account_name).first
        instance_variable_set("@cached_account_#{sanitized_account_name}", a)
      end

      if a.nil?
        return nil
      else
        return local_value_for_account(attr_name,a._id)
      end
    # local_unique_attribute setter for an account_name
    elsif method_sym.to_s =~ /^(.+)_for_(.+)=$/
      attr_name = $1
      account_name = $2
      sanitized_account_name = account_name.gsub(/\.|-/, '_')
      a = nil

      #cache account to avoid multiple calls to accounts service
      if (a = instance_variable_get("@cached_account_#{sanitized_account_name}")).blank?
        a = NewAccount.where(name: account_name).first
        instance_variable_set("@cached_account_#{sanitized_account_name}", a)
      end

      if a.nil?
        raise 'account_id not found'
      else
        ac = self.account_contacts.where(:account_id => a.id).first
        if ac.nil?
          ac = self.account_contacts.new(:account_id => a.id)
          ac.send(attr_name + "=", arguments.first)
        else
          ac.send(attr_name + "=", arguments.first)
        end
        ac.save
        return
      end
    else
      super
    end
  end

  def respond_to?(method_sym, include_private = false)
    if method_sym.to_s =~ /^(.+)_for_(.+)=?$/
      true
    else
      super
    end
  end

  protected

  def ensure_linked_to_owner
    if self.owner.present? && !self.owner.in?(self.accounts)
      self.accounts << self.owner
    end
  end

  def assign_owner
    old_owner_id = self.owner_id

    new_owner = case self.status.try(:to_sym)
      when :student
        self.account_contacts.where(local_status: :student).first.try :account
      when :former_student
        if self.owner.nil?
          self.account_contacts
              .where(local_status: :former_student).first.try :account
        end
      else
        if self.owner.nil?
          self.accounts.first
        end
    end

    if new_owner && new_owner.id != old_owner_id
      self.owner = new_owner
      self.skip_assign_owner = true
      self.save(validate: false)
      
      # Callbacks arent called when mass-assigning nested models.
      # Iterate over the contact_attributes and set the owner.
      # TODO cascade_callbacks should make this un-necessary
      #contact_attributes.each do |att|
      #  att.account = owner unless att.account.present?
      #end
    end
  end
end
