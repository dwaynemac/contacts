# encoding: UTF-8
class NewContact < ActiveRecord::Base
  
  VALID_STATUSES = [:student, :former_student, :prospect] # they are ordered by precedence (first has precedence)
  VALID_COEFFICIENTS = {
    "unknown" => 0,
    "fp" => 1,
    "pmenos" => 2,
    "perfil" => 3,
    "pmas" => 4
  } # Order is important and used.

  self.table_name = "contacts"
  has_objectid_primary_key

  has_many :account_contacts, foreign_key: :contact_id
  has_many :accounts, through: :account_contacts, foreign_key: :contact_id, class_name: "NewAccount"
  alias_method :linked_accounts, :accounts

  has_many :contact_attributes, foreign_key: :contact_id, class_name: "NewContactAttribute"
  
  validates_associated :contact_attributes
  accepts_nested_attributes_for :contact_attributes, :allow_destroy => true

  belongs_to :owner, class_name: "NewAccount"

  mount_uploader :avatar, AvatarUploader

  has_many :attachments, foreign_key: :contact_id, class_name: "NewAttachment" #, cascade_callbacks: true
  accepts_nested_attributes_for :attachments, allow_destroy: true
 
  before_save :ensure_linked_to_owner
  before_save :update_normalized_attributes
  before_save :capitalize_first_and_last_names

  attr_accessor :skip_set_status
  attr_accessor :skip_assign_owner
  attr_accessor :skip_level_change_activity # default: nil
  attr_accessor :check_duplicates # default: false
  attr_accessor :skip_history_entries # default: nil
  attr_accessor :request_username
  attr_accessor :request_account_name

  after_save :assign_owner, unless: :skip_assign_owner
  after_save :post_activity_if_level_changed
  after_save :keep_history_of_changes

  before_validation :set_status, unless: :skip_set_status
  before_validation :set_global_teacher
  
  validates_inclusion_of :status, in: VALID_STATUSES, allow_blank: true

  validates :first_name, presence: true

  validates :kshema_id, uniqueness: true, allow_blank: true
  validates :derose_id, uniqueness: true, allow_blank: true

  validates :estimated_age, numericality: true,  allow_blank: true

  validates_inclusion_of :gender, in: %W(male female), allow_blank: true  
  validate :validate_duplicates, :if => :check_duplicates, on: :create

  # ordered by hierarchy (last is higher)
  VALID_LEVELS = {
    "aspirante" => 0,
    "sádhaka" => 1,
    "yôgin" => 2,
    "chêla" => 3,
    "graduado" => 4,
    "asistente" => 5,
    "docente" => 6,
    "maestro" => 7
  }

  # @return [String]
  def level
    VALID_LEVELS.key(read_attribute(:level))
  end

  # Setter for level overriden to keep integers values for proper sorting
  # @param s [String]
  def level=(s)
    write_attribute(:level, VALID_LEVELS[s])
  end

  TYPES = %W(email telephone address custom_attribute date_attribute identification occupation attachment social_network_id)

  TYPES.each do |k|
    define_method k.pluralize do
      self.contact_attributes.select {|c| c.type == "New" + k.camelcase }
    end
  end
  
  def mobiles
   self.contact_attributes.select {|c| c.type == "NewTelephone" and  c.category == "mobile" }
  end

  def birthday
    self.date_attributes.select {|c| c.category == "birthday"}.first
  end

  def local_statuses
  	self.account_contacts.collect(&:local_status)
  end

  def local_teachers
    self.account_contacts.collect(&:local_teacher_username)
  end

  def coefficients
    self.account_contacts.collect(&:coefficient)
  end
  
  def status
  	return self[:status].try(:to_sym)
  end
  
  attr_accessor :cached_owner
  alias_method :orig_owner, :owner
  def owner
    #cache account to avoid multiple calls to accounts service
    if @cached_owner.blank?
      @cached_owner = orig_owner
    end
    @cached_owner
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

  def set_global_teacher
    return if self.owner.nil?
    teacher_in_owner_accounts = self.account_contacts.where(account_id: self.owner.id).first
    if !teacher_in_owner_accounts.nil? && (teacher_in_owner_accounts.local_teacher_username != self.global_teacher_username)
      self.global_teacher_username = teacher_in_owner_accounts.local_teacher_username
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
        return local_value_for_account(attr_name,a.id)
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

  def coefficients_counts
    VALID_COEFFICIENTS.keys.map{ |vv| {vv => self.coefficients.count {|coeff| coeff == vv}} }.inject(:merge)
  end

  def add_contact_to_mailchimp(reference_email = nil)
    # check whether account is subscribed to mailchimp
    ms = owner.nil? ? [] : MailchimpSynchronizer.where(account_id: owner.id)
    unless ms.empty?
      ms.first.subscribe_contact(id)
    end
  end

  def update_contact_in_mailchimp(reference_email = nil)
    # check whether account is subscribed to mailchimp
    ms = MailchimpSynchronizer.where(:account_id.in => linked_accounts.map(&:id))
    unless ms.empty?
      # do not update contact if this is the first time email is set
      ms.each do |m|
        reference_email = primary_attribute(
          Account.find(m.account_id), "Email"
          ).value if reference_email.nil? && primary_attribute(Account.find(m.account_id), "Email")
        m.update_contact(id, reference_email) unless reference_email.blank?
      end
    end
  end

  def delete_contact_from_mailchimp(email = nil)
    # check whether account is subscribed to mailchimp
    ms = owner.nil? ? [] : MailchimpSynchronizer.where(account_id: owner.id)
    unless ms.empty?
      email = primary_attribute(owner, "Email").value if email.nil? && primary_attribute(owner, "Email")
      ms.first.unsubscribe_contact(id, email, false) unless email.blank?
    end
  end

  def primary_attribute(account, type)
    pa = self.contact_attributes.where({
      account_id: account.id,
      type: type,
      primary: true
    }).first
  end

  def global_primary_attribute(type)
    pa = self.contact_attributes.where({
      type: type,
      primary: true
    }).last
  end

  def active_merges
    NewMerge.where("state != 'merged' AND (first_contact_id = '#{self.id}' OR second_contact_id = '#{self.id}')")
  end

  # Checks if contact is currently in a non-finished merge.
  # @return [TrueClass]
  def in_active_merge?
    (active_merges.count > 0)
  end
  alias_method :in_active_merge, :in_active_merge? # alias for json. ? is not valid attribute name for client.

  def owner_name
    ActiveSupport::Notifications.instrument('owner_name.contact') do
      return nil if self.owner_id.nil?
      if @owner_name.nil?
        @owner_name = NewAccount.name_for_id(self.owner_id)
      end
      return @owner_name
    end
  end

  def owner_name=(name)
    self.owner = NewAccount.where(:name => name).first
    @owner_name = self.owner.try(:name)
  end

  # Returns contacts that are similar to this one.
  # @return [Array<Contact>]
  def similar(options = {})
    ActiveSupport::Notifications.instrument("get_similar_contacts") do
      if options[:only_in_account_name]
        contacts = NewAccount.where(name: options[:only_in_account_name]).first.contacts.includes(:contact_attributes)
      else
        contacts = NewContact.includes(:contact_attributes)
      end

      @filters = []
      
      unless options[:ignore_name]
        if self.last_name.blank?
          unless self.first_name.blank?
            self.first_name.split.each do |first_name|
              @filters << "normalized_first_name REGEXP '.*#{first_name.parameterize}.*'"
            end
          end
        else
          self.last_name.split.each do |last_name|
            self.first_name.split.each do |first_name|
              @filters << "normalized_last_name REGEXP '.*#{last_name.parameterize}.*' AND normalized_first_name REGEXP '.*#{first_name.parameterize}.*'"
            end
          end
        end
      end

      self.emails.map(&:value).each do |email|
        @filters << "contact_attributes.type = 'NewEmail' AND contact_attributes.string_value = '#{email}'"
      end

      self.mobiles.map(&:value).each do |mobile|
        @filters << "contact_attributes.type = 'NewTelephone' AND LOWER(contact_attributes.category) = 'mobile' AND contact_attributes.string_value = '#{mobile}'"
      end
      
      self.telephones.select{|t| t.category.blank? }.map(&:value).each do |telephone|
        @filters << "contact_attributes.type = 'NewTelephone' AND contact_attributes.string_value = '#{telephone}'"
      end

      self.identifications.each do |identification|
        @filters << "contact_attributes.type = 'NewIdentification' AND contact_attributes.category = '#{identification.category}' AND contact_attributes.string_value = '#{identification.get_normalized_value}'"
      end
      
      if @filters.empty?
        return []
      else
        contacts = contacts.any_of(*@filters)
      end

      if self.id.present?
        contacts = contacts.where("contacts.id != '#{self.id}'")
      end

      contacts = contacts.to_a

      contacts.delete_if do |c|
        not_similar = false
        c.identifications.each do |id|
          if self.identifications.select {|i| i.category == id.category}.select{ |id_v|
              id_v.get_normalized_value != id.get_normalized_value
            }.length > 0
            not_similar = true
          end
        end
        not_similar
      end
    end
  end

  # @return [Hash] Returns the minimal representation of this contact
  # A hash including :_id, :first_name and :last_name
  def minimum_representation
    {
        :_id => id,
        :first_name => first_name,
        :last_name => last_name
    }
  end

  # @return [Hash] like errors.messages but it specifies error messages for :contact_attributes
  def deep_error_messages
    error_messages = self.errors.messages.dup

    # todo include here local_unique_attributes errors
    [:contact_attributes, :local_unique_attributes].each do |k|
      if error_messages[k]
        error_messages[k] = self.send(k).reject(&:valid?).map do |obj|
          obj.errors.messages.map do |attr,messages|
            if attr == :value
              "#{obj.value} #{messages.join(', ')}"
            elsif attr != :possible_duplicates
              "#{attr} #{obj.send(attr)} #{messages.join(', ')}"
            end
          end.flatten
        end
      end
    end

    error_messages
  end


  protected

  def capitalize_first_and_last_names
    self.first_name = self.first_name.slice(0,1).capitalize + self.first_name.slice(1..-1) unless self.first_name.blank?
    self.last_name = self.last_name.slice(0,1).capitalize + self.last_name.slice(1..-1) unless self.last_name.blank?
  end

  def ensure_linked_to_owner
    if self.owner.present? && !self.owner.in?(self.accounts)
      self.accounts << self.owner
    end
  end

  def validate_duplicates
    duplicates = self.similar
    unless duplicates.empty?
      self.errors[:duplicates] << I18n.t('errors.messages.could_have_duplicates')
      self.errors[:possible_duplicates] = duplicates.map {|c| c.minimum_representation}
    end
  end

  def update_normalized_attributes
    self.normalized_first_name = self.first_name.try :parameterize
    self.normalized_last_name = self.last_name.try :parameterize
  end

  def request_account
    #cache account to avoid multiple calls to accounts service
    if @cached_request_account.blank?
      @cached_request_account = Account.where(name: self.request_account_name).first
    end
    @cached_request_account  
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
      @cached_owner = new_owner
      self.save(validate: false)
      
      # Callbacks arent called when mass-assigning nested models.
      # Iterate over the contact_attributes and set the owner.
      # TODO cascade_callbacks should make this un-necessary
      contact_attributes.each do |att|
        att.account = owner unless att.account.present?
      end
    end
  end

  def keep_history_of_changes
    unless skip_history_entries
      # level, global_status and teacher_username
      %W(level status global_teacher_username in_professional_training professional_training_level).each do |att|
        if self.send("#{att}_changed?")
          self.history_entries.create(attribute: att,
                                      changed_at: Time.zone.now.to_time,
                                      old_value: self.changes[att][0])
        end
      end
      # local_status changes are tracked in LocalStatus model
      # local_teacher changes are tracked in LocalTeacher model
    end
  end

  def post_activity_if_level_changed
    unless skip_level_change_activity
      if level_changed?
        activity_username = request_username     || global_teacher_username
        activity_account  = request_account_name || owner_name

        a = ActivityStream::Activity.new(
            username: activity_username,
            account_name: activity_account,
            content: "#{level}",
            generator: 'contacts',
            verb: 'updated',
            target_id: id, target_type: 'Contact',
            object_id: id, object_type: 'Contact',
            public: true
        )
        a.create(username: activity_username, account_name: activity_account)
      end
    end
  end
end
