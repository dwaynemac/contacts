# encoding: UTF-8
require 'mongoid/criteria'

##
# @restful_api v0
#
# @property [String] first_name
# @property [String] last_name
#
# @property [String] gender Valid values are '', 'male' and 'female'.
class Contact
  include Mongoid::Document
  include Mongoid::Timestamps

  include Mongoid::Search
  
  include Contact::Tagging
  references_and_referenced_in_many :tags

  #before_destroy :delete_contact_from_mailchimp
  search_in :first_name, :last_name, {:contact_attributes => :value }, {:tags => :name} , {:ignore_list => Rails.root.join("config", "search_ignore_list.yml"), :match => :all}

  embeds_many :attachments, cascade_callbacks: true
  accepts_nested_attributes_for :attachments, allow_destroy: true

  embeds_many :contact_attributes, :validate => true, :cascade_callbacks => true

  before_validation :manually_set_date_attribute_values
  
  validates_associated :contact_attributes
  accepts_nested_attributes_for :contact_attributes, :allow_destroy => true

  embeds_many :local_unique_attributes, validate: true, cascade_callbacks: true
  validates_associated :local_unique_attributes
  accepts_nested_attributes_for :local_unique_attributes, allow_destroy: true

  has_many :history_entries, as: 'historiable', dependent: :delete
  after_save :keep_history_of_changes
  #after_update :update_contact_in_mailchimp
  attr_accessor :skip_history_entries # default: nil

  after_save :post_activity_if_level_changed
  attr_accessor :skip_level_change_activity # default: nil

  after_create :post_activity_of_creation
  #after_create :add_contact_to_mailchimp


  field :first_name
  field :last_name

  before_save :capitalize_first_and_last_names

  field :normalized_first_name
  field :normalized_last_name
  before_save :update_normalized_attributes

  field :gender
  validates_inclusion_of :gender, in: %W(male female), allow_blank: true

  field :avatar
  mount_uploader :avatar, AvatarUploader

  field :level, type: Integer

  field :estimated_age, type: Integer
  validates_numericality_of :estimated_age, allow_blank: true

  before_save :set_estimated_age_on
  field :estimated_age_on, type: Date

  # DeRose ID is a uniq identified for students of DeRose Method Network
  # eg: "AR BEL 2015 0 123-3"
  field :derose_id
  validates_uniqueness_of :derose_id, allow_blank: true

  field :first_enrolled_on, type: Date

  field :kshema_id
  validates_uniqueness_of :kshema_id, allow_blank: true
  
  field :slug
  validates_uniqueness_of :slug, allow_blank: true
  before_save :set_slug

  field :publish_on_gdp

  field :in_professional_training, type: Boolean
  
  field :professional_training_level, type: Integer
  # 1 - profu, 2 - comple, 3 - 3rd_module
  VALID_PROFESSIONAL_TRAINING_LEVEL = [1, 2, 3]

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

  VALID_STATUSES = [:student, :former_student, :prospect] # they are ordered by precedence (first has precedence)

  field :status, type: Symbol
  attr_accessor :skip_set_status
  before_validation :set_status, unless: :skip_set_status
  validates_inclusion_of :status, :in => VALID_STATUSES, :allow_blank => true

  before_save :set_beginner_on_enrollment

  # accounts that have access to this contact.
  # These are the accounts the contact is 'linked' to.
  has_and_belongs_to_many :accounts, dependent: :nullify
  alias_method :linked_accounts, :accounts

  belongs_to :owner, :class_name => "Account"

  attr_accessor :skip_assign_owner
  after_save :assign_owner, unless: :skip_assign_owner
  before_save :ensure_linked_to_owner

  field :global_teacher_username, type: String
  before_validation :set_global_teacher

  references_and_referenced_in_many :lists

  validates :first_name, :presence => true

  attr_accessor :check_duplicates # default: false
  validate :validate_duplicates, :if => :check_duplicates, on: :create

  attr_accessor :request_username
  attr_accessor :request_account_name
  
  def set_slug
    if self.slug.blank?
      i = 0
      presufix = self._id.to_s.last(3)
      sufix = presufix
      begin
        self.slug = "#{full_name.parameterize}-#{sufix}"
        i += 1
        sufix = "#{presufix}#{i}"
      end while (!Contact.where(slug: self.slug).empty?) 
    elsif self.slug_changed?
      self.slug = self.slug.parameterize
    end
  end

  # @return [Mongoid::Criteria]
  def active_merges
    Merge.any_of({first_contact_id: self.id}, {second_contact_id: self.id}).excludes(state: :merged)
  end

  # Checks if contact is currently in a non-finished merge.
  # @return [TrueClass]
  def in_active_merge?
    (active_merges.count > 0)
  end
  alias_method :in_active_merge, :in_active_merge? # alias for json. ? is not valid attribute name for client.

  # @return [String]
  def full_name
    "#{first_name} #{last_name}"
  end

  # Level getter/setter overriden to keep integers values for proper sorting

  # @return [String]
  def level
    VALID_LEVELS.key(read_attribute(:level))
  end

  # Setter for level overriden to keep integers values for proper sorting
  # @param s [String]
  def level=(s)
    write_attribute(:level, VALID_LEVELS[s])
  end

  # defines Contact#emails/telephones/addresses/custom_attributes/etc
  # they all return a Criteria scoping to according _type
  %W(email
     telephone
     address
     custom_attribute
     date_attribute
     identification
     occupation
     contact_attachment
     social_network_id
  ).each do |k|
    delegate k.pluralize, to: :contact_attributes
  end

  # @return [Array<Telephone>] mobile telephones embedded in this contact
  def mobiles
    self.contact_attributes.telephones.mobiles
  end

  def birthday
    self.date_attributes.where(category: 'birthday').first
  end

  # defines Contact#coefficients/...
  # they all return a Criteria scoping to according _type
  %W(coefficient local_status local_teacher observation last_seen_at).each do |lua|
    delegate lua.pluralize, to: :local_unique_attributes
  end

  # Setter for local_status of a certain account_id
  # This allows a cleaner API for update /accounts/account_id/contacts usage
  # @author Dwayne Macgowan
  # @param options [Hash]
  # @option options [String] :account_id
  # @option options [Symbol] :status this should be a valid status
  # @raise [ArgumentError] if :account_id is not given
  #
  # @example @contact.local_status = account_id: acc.id, status: :student
  #
  # @example
  #   params[:contact][:local_status] = {:account_id => @account_id.id, :status => params[:contact].delete(:local_status)}
  #   @contact.update_attributes(params[:contact])
  #
  # @return [LocalStatus]
  def local_status=(options)
    return unless options.is_a?(Hash)
    ls = self.local_statuses.where(:account_id => options[:account_id]).first
    if ls.nil?
      ls = LocalStatus.new(account_id: options[:account_id], value: options[:status])
      self.local_unique_attributes << ls
    else
      ls.status = options[:status]
    end
    ls
  end

  # @return LocalUniqueAttribute.value 
  def local_value_for_account(attr_name,account_id)
    return self.local_unique_attributes
               .where(account_id: account_id, '_type' => attr_name.camelcase)
               .first
               .try :value
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
        a = Account.where(name: account_name).first
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
        a = Account.where(name: account_name).first
        instance_variable_set("@cached_account_#{sanitized_account_name}", a)
      end

      if a.nil?
        raise 'account_id not found'
      else
        lua = self.local_unique_attributes.where(:account_id => a._id, '_type' => attr_name.camelcase).first
        if lua.nil?
          self.local_unique_attributes << attr_name.camelcase.constantize.new(account: a, value: arguments.first)
        else
          lua.value = arguments.first
        end
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
    Coefficient::VALID_VALUES.map{ |vv| {vv => self.coefficients.where(value: vv).count} }.inject(:merge)
  end

  # If account_id is specified some addtional attributes are added:
  #   - linked [TrueClass] whether or not this contact is linked to given account
  #   - last_local_status [String] last local status on given account
  #   - local_teacher [String] username of teacher in given account
  #
  # @param [Hash] options
  # @option options [Account] account
  # @option options [TrueClass] include_masked
  # @option options [Array] select. List of attribute names to incluse in response.
  #                                 You can also send attribute name as key, and reference_date as value to know
  #                                 attribute's value at a given time.
  #
  #                         eg: select: [:first_name, :last_name, level: '2012-1-1']
  def as_json(options = {})
    attributes = {}

    attributes[:mode] = options[:mode]
    attributes[:contact] = self
    attributes[:select] = options[:select].class == Array ? options[:select].reject{|v| v.nil?} : options[:select]
    attributes[:account] = options[:account]
    attributes[:include_masked] = options[:include_masked]
    attributes[:except] = {
      except_linked: options[:except_linked],
      except_last_local_status: options[:except_last_local_status]
    }
        
    cs = ContactSerializer.new(attributes)
    cs.serialize
  end

  def primary_attribute(account, type)
    pa = self.contact_attributes.where({
      account_id: account.id,
      _type: type,
      primary: true
    }).first
  end

  def global_primary_attribute(type)
    pa = self.contact_attributes.where({
      _type: type,
      primary: true
    }).last
  end

  # @see Account#link
  def link(account)
    account.link(self)
  end

  # @see Account#unlink
  def unlink(account)
    #delete_contact_from_mailchimp
    account.unlink(self)
  end

  # @see Account#linked_to?
  def linked_to?(account)
    account.id.in?(self.account_ids)
  end

  def owner_name
    ActiveSupport::Notifications.instrument('owner_name.contact') do
      return nil if self.owner_id.nil?
      if @owner_name.nil?
        @owner_name = Account.name_for_id(self.owner_id)
      end
      return @owner_name
    end
  end

  def owner_name=(name)
    self.owner = Account.where(:name => name).first
    @owner_name = self.owner.try(:name)
  end

  # Updates global_status (#status) and saves contact
  def update_status!
    self.set_status
    self.save(validate: false)
  end

  # Updates global_teacher_username and saves contact
  def update_global_teacher!
    self.set_global_teacher
    self.save
  end

  # Returns contacts that are similar to this one.
  # @return [Array<Contact>]
  def similar(options = {})
    ActiveSupport::Notifications.instrument("get_similar_contacts") do
      if options[:only_in_account_name]
        contacts = Account.where(name: options[:only_in_account_name]).first.contacts
      else
        contacts = Contact.all
      end
      
      @unfiltered = true
      
      unless options[:ignore_name]
        if self.last_name.blank?
          unless self.first_name.blank?
            self.first_name.split.each do |first_name|
              @unfiltered = false
              contacts = contacts.any_of(:normalized_first_name => {'$regex' => ".*#{first_name.parameterize}.*"})
            end
          end
        else
          self.last_name.split.each do |last_name|
            self.first_name.split.each do |first_name|
              @unfiltered = false
              contacts = contacts.any_of(:normalized_last_name => {'$regex' => ".*#{last_name.parameterize}.*"},
                                         :normalized_first_name => {'$regex' => ".*#{first_name.parameterize}.*"})
            end
          end
        end
      end

      self.emails.map(&:value).each do |email|
        @unfiltered = false
        contacts = contacts.any_of(contact_attributes: { '$elemMatch' => {
                                                        '_type' => 'Email',
                                                        'value' => email,
        }})
      end

      self.mobiles.map(&:value).each do |mobile|
        @unfiltered = false
        contacts = contacts.any_of(contact_attributes: {'$elemMatch' => {
          '_type' => 'Telephone',
          'category' => /mobile/i,
          'value' => mobile
        }})
      end
      
      self.telephones.select{|t| t.category.blank? }.map(&:value).each do |telephone|
        @unfiltered = false
        contacts = contacts.any_of(contact_attributes: {'$elemMatch' => {
          '_type' => 'Telephone',
          'value' => telephone
        }})
      end

      self.identifications.each do |identification|
        @unfiltered = false
        contacts = contacts.any_of(contact_attributes: {'$elemMatch' => {
            _type: 'Identification',
            category: identification.category,
            value: identification.get_normalized_value
        }})
      end
      
      if @unfiltered
        return []
      end

      if self.id.present?
        contacts = contacts.excludes(:id => self.id)
      end

      contacts = contacts.to_a

      contacts.delete_if do |c|
        not_similar = false
        c.identifications.each do |id|
          if self.identifications.where(:category => id.category).select{ |id_v|
              id_v.get_normalized_value != id.get_normalized_value
            }.length > 0
            not_similar = true
          end
        end
        not_similar
      end
    end
  end

  def check_duplicates= value
    if value.is_a? String
      @check_duplicates = value == "true"
    else
      @check_duplicates = value
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

  def self.with_custom_attributes
    self.where( contact_attributes: { '$elemMatch' => { _type: 'CustomAttribute'}})
  end

  def attribute_value_at(attribute,ref_date)
    HistoryEntry.value_at(attribute,ref_date,{class: 'Contact',id: self.id}) || self.send(attribute)
  end

  ##
  # @param attribute [String]
  # @param value. Will be casted according to attribute. Level must be given as a string. eg: 'aspirante'
  # @param ref_date [Date]
  # @param account_name [String]
  # @return [Mongoid::Criteria]
  def self.with_attribute_value_at(attribute, value, ref_date, account_name = nil)
    if ref_date.is_a?(Date) && !ref_date.is_a?(DateTime)
      ref_date = ref_date.to_datetime.end_of_day
    end

    if current_month?(ref_date)
      self.api_where(attribute => value)
    else
      # cast value
      value = case attribute
        when 'level'
          VALID_LEVELS[value]
        else
          value
      end

      ids = HistoryEntry.element_ids_with(
          attribute => value,
          at: ref_date,
          class: 'Contact',
          account_name: account_name
      )
      self.any_in(_id: ids)
    end
  end

  def self.api_where(selector = nil, account_id = nil)
    ContactSearcher.new(self, account_id).api_where(selector)
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
    distinct_statuses = local_statuses.distinct(:value).compact.map(&:to_sym)
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
    teacher_in_owner_accounts = self.local_teachers.for_account(self.owner.id).first
    if !teacher_in_owner_accounts.nil? && (teacher_in_owner_accounts.teacher_username != self.global_teacher_username)
      self.global_teacher_username= teacher_in_owner_accounts.teacher_username
    end
  end

  protected

  def assign_owner
    old_owner_id = self.owner_id

    new_owner = case self.status.try(:to_sym)
      when :student
        self.local_statuses.where(value: :student).first.try :account
      when :former_student
        if self.owner.nil?
          self.local_statuses
              .where(value: :former_student).first.try :account
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
      contact_attributes.each do |att|
        att.account = owner unless att.account.present?
      end
    end
  end

  def ensure_linked_to_owner
    if self.owner.present? && !self.owner.id.in?(self.account_ids)
      self.account_ids << self.owner.id
    end
  end

  def update_normalized_attributes
    self.normalized_first_name = self.first_name.try :parameterize
    self.normalized_last_name = self.last_name.try :parameterize
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

  # POSTs an Activity to ActivityStream if request_user && request_account are set.
  def post_activity_of_creation
    unless self.request_username.blank? || self.request_account.blank?
      entry = ActivityStream::Activity.new(
          target_id: self.owner_name, target_type: 'Account',
          object_id: self._id, object_type: 'Contact',
          generator: 'contacts',
          verb: 'created',
          content: "#{self.request_username} created #{self.full_name} on #{self.owner_name}",
          public: true,
          username: self.request_username,
          account_name: self.request_account_name,
          created_at: Time.zone.now.to_s,
          updated_at: Time.zone.now.to_s
      )
      entry.create(username:  self.request_username, account_name: self.request_account_name)
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

  def validate_duplicates
    duplicates = self.similar
    unless duplicates.empty?
      self.errors[:duplicates] << I18n.t('errors.messages.could_have_duplicates')
      self.errors[:possible_duplicates] = duplicates.map {|c| c.minimum_representation}
    end
  end

  def set_estimated_age_on
    if estimated_age_changed?
      self.estimated_age_on = estimated_age.blank?? nil : Date.today
    end
  end

  def set_beginner_on_enrollment
    if status_changed? && status == :student && self.level.nil?
      self.level = 'aspirante'
    end
  end

  def request_account
    #cache account to avoid multiple calls to accounts service
    if @cached_request_account.blank?
      @cached_request_account = Account.where(name: self.request_account_name).first
    end
    @cached_request_account  
  end
  
  private

  def capitalize_first_and_last_names
    self.first_name = self.first_name.slice(0,1).capitalize + self.first_name.slice(1..-1) unless self.first_name.blank?
    self.last_name = self.last_name.slice(0,1).capitalize + self.last_name.slice(1..-1) unless self.last_name.blank?
  end

  def self.current_month?(ref_date)
    if ref_date.is_a?(String)
      ref_date = DateTime.parse(ref_date)
    end
    (ref_date.year == Date.today.year && ref_date.month == Date.today.month)
  end

  # Mongoid doesnt trigger before_validation on embedded documents so we trigger it manually
  def manually_set_date_attribute_values
    date_attributes.each do |da|
      if da.new_record?
        da.value = DateAttribute.new(da.attributes).set_value
      end
    end
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
    ms = MailchimpSynchronizer.where(:account_id.in => linked_accounts.map(&:_id))
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

end
