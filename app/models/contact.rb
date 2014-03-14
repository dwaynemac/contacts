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
  search_in :first_name, :last_name, {:contact_attributes => :value }, {:tags => :name} , {:ignore_list => Rails.root.join("config", "search_ignore_list.yml"), :match => :all}

  embeds_many :attachments, cascade_callbacks: true
  accepts_nested_attributes_for :attachments, allow_destroy: true

  embeds_many :contact_attributes, :validate => true, :cascade_callbacks => true
  validates_associated :contact_attributes
  accepts_nested_attributes_for :contact_attributes, :allow_destroy => true

  embeds_many :local_unique_attributes, validate: true, cascade_callbacks: true
  validates_associated :local_unique_attributes
  accepts_nested_attributes_for :local_unique_attributes, allow_destroy: true

  has_many :history_entries, as: 'historiable', dependent: :delete
  after_save :keep_history_of_changes
  attr_accessor :skip_history_entries # default: nil

  after_save :post_activity_if_level_changed
  attr_accessor :skip_level_change_activity # default: nil

  after_create :post_activity_of_creation

  field :first_name
  field :last_name

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

  field :kshema_id
  validates_uniqueness_of :kshema_id, allow_blank: true

  field :publish_on_gdp

  field :in_professional_training, type: Boolean

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

  belongs_to :owner, :class_name => "Account"

  attr_accessor :skip_assign_owner
  before_validation :assign_owner, unless: :skip_assign_owner

  field :global_teacher_username, type: String
  before_validation :set_global_teacher

  references_and_referenced_in_many :lists
  before_save :update_lists

  references_and_referenced_in_many :tags

  validates :first_name, :presence => true

  attr_accessor :check_duplicates # default: true
  validate :validate_duplicates, :if => :check_duplicates, on: :create

  attr_accessor :request_username
  attr_accessor :request_account_name

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
  %W(email telephone address custom_attribute date_attribute identification contact_attachment social_network_id).each do |k|
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
  %W(coefficient local_status local_teacher observation).each do |lua|
    delegate lua.pluralize, to: :local_unique_attributes
  end

  def tag_ids_for_request_account
    account = self.request_account
    if account.nil?
      return nil
    else
      tags.where(account_id: account.id).map(&:id)
    end
  end

  def tag_ids_for_request_account=(ids)
    unless ids.is_a? Array
      ids = []
    end
    account = self.request_account
    if account.nil?
      raise 'missing account'
    else
      previous_ids = tags.where(account_id: {"$ne" => account.id}).map(&:id)

      # Initialice Tags for contact.index_keywords to work
      new_tags = Tag.find(previous_ids+ids)
      self.tags = new_tags.empty? ? nil : new_tags
    end
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
        return self.local_unique_attributes.where(:account_id => a._id, '_type' => attr_name.camelcase).first.try :value
      end
    # local_unique_attribute setter for an account_name
    elsif method_sym.to_s =~ /^(.+)_for_(.+)=$/
      attr_name = $1
      account_name = $2
      sanitized_account_name = account_name.gsub('.', '_')
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
    ActiveSupport::Notifications.instrument('as_json.contact') do
      # select: [ :first_name, :last_name, level: { at: date }
      options.reverse_merge!({select: [:first_name, :last_name]})
      # only_name option is a special case used for typeahead selection (for example on attendance app)
      # TODO: move this option as a select param (same as 'all')
      if options[:only_name]
        json = {}
        json[:id] = self.id
        json[:name] = self.full_name
      # if select is an array (of attribute names)  
      elsif options[:select].present? && options[:select].kind_of?(Array)

        # symbolize select keys, separate value_at_time attributes.
        value_at_selects = options[:select].select{|i|i.is_a?(Hash)}
        options[:select] = options[:select].reject{|i|i.is_a?(Hash)}.map{|i| i.to_sym }

        # always include id
        options[:select] << :_id unless options[:select].include? :_id

        if options[:select].include? :full_name
          options[:select] << :first_name
          options[:select] << :last_name
        end

        # select all attributes except for special ones
        options = options.merge({:only => options[:select], :except => [:contact_attributes, :tags, :local_status, :coefficient, :local_teacher, :observation, :local_unique_attributes, :tag_ids, :owner_id, :history_entries]})

        json = super options

        # add attributes at specific times
        value_at_selects.each do |pair|
          attribute = pair.keys.first
          ref_date = pair[attribute]
          json[attribute] = self.attribute_value_at(attribute,ref_date)
        end


        account = options[:account]
        if account
          #select contact_attributes for the calling account
          json[:contact_attributes] = self.contact_attributes.for_account(account, options) if options[:select].include? :contact_attributes
          # tags
          json[:tags] = self.tags.where(account_id: account.id) if options[:select].include? :tags
          # local_attributes
          %w{local_status coefficient local_teacher observation}.each do |local_attribute|
            json[local_attribute] = self.send("#{local_attribute}_for_#{account.name}")  if options[:select].include? local_attribute.to_sym
          end
        end
        json
      # if select is present and wants all attributes, behave as before.
      # do this also if select isnt present.
      elsif options[:select].nil? || options[:select] == "all"
        account = options[:account]
        if account
          # add these options when account_id specified
          options = options.merge({:except => [:contact_attributes, :local_unique_attributes, :tag_ids]})
        end

        options = options.merge({:except => [:owner_id, :history_entries],
                                 :methods => [:owner_name,
                                              :local_statuses,
                                              :coefficients_counts,
                                              :in_active_merge
                                 ]})

        json = super options

        if account
          # add these data when account_id specified
          json[:contact_attributes] = self.contact_attributes.for_account(account, options)
          json[:tags] = self.tags.where(account_id: account.id)
          %w{local_status coefficient observation local_teacher}.each do |local_attribute|
            json[local_attribute] = self.send("#{local_attribute}_for_#{account.name}")
          end
          json[:linked] = self.linked_to?(account) unless options[:except_linked]
          json[:last_local_status] = self.history_entries.last_value("local_status_for_#{account.name}".to_sym) unless options[:except_last_local_status]
        end      
      end
      json
    end
  end

  # @see Account#link
  def link(account)
    account.link(self)
  end

  # @see Account#unlink
  def unlink(account)
    account.unlink(self)
  end

  # @see Account#linked_to?
  def linked_to?(account)
    account.linked_to?(self)
  end

  def owner_name
    self.owner.try :name
  end

  def owner_name=(name)
    self.owner = Account.where(:name => name).first
  end

  # Updates global_status (#status) and saves contact
  def update_status!
    self.set_status
    self.save
  end

  # Updates global_teacher_username and saves contact
  def update_global_teacher!
    self.set_global_teacher
    self.save
  end

  # Returns contacts that are similar to this one.
  # @return [Array<Contact>]
  def similar
    contacts = Contact.all

    if self.last_name.blank?
      unless self.first_name.blank?
        self.first_name.split.each do |first_name|
          contacts = contacts.any_of(:normalized_first_name => {'$regex' => ".*#{first_name.parameterize}.*"})
        end
      end
    else
      self.last_name.split.each do |last_name|
        self.first_name.split.each do |first_name|
          contacts = contacts.any_of(:normalized_last_name => {'$regex' => ".*#{last_name.parameterize}.*"},
                                     :normalized_first_name => {'$regex' => ".*#{first_name.parameterize}.*"})
        end
      end
    end

    if self.new?
      self.emails.map(&:value).each do |email|
        contacts = contacts.any_of(contact_attributes: { '$elemMatch' => {
                                                        '_type' => 'Email',
                                                        'value' => email,
        }})
      end

      self.mobiles.map(&:value).each do |mobile|
        contacts = contacts.any_of(contact_attributes: {'$elemMatch' => {
          '_type' => 'Telephone',
          'category' => /mobile/i,
          'value' => mobile
        }})
      end

      self.identifications.each do |identification|
        contacts = contacts.any_of(contact_attributes: {'$elemMatch' => {
            _type: 'Identification',
            category: identification.category,
            value: identification.get_normalized_value
        }})
      end
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

  def check_duplicates= value
    if value.is_a? String
      @check_duplicates = value == "true"
    else
      @check_duplicates = value
    end
  end

  def check_duplicates
    @check_duplicates.nil? ? true : @check_duplicates
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
            else
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
  # @return [Mongoid::Criteria]
  def self.with_attribute_value_at(attribute, value, ref_date)
    if ref_date.is_a?(Date) && !ref_date.is_a?(DateTime)
      ref_date = ref_date.to_datetime.end_of_day
    end

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
        class: 'Contact'
    )
    self.any_in(_id: ids)
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

  # @return [Array<Account>]
  def linked_accounts
    self.lists.map(&:account).uniq
  end

  protected

  def assign_owner
    case self.status
      when :student
        self.owner = self.local_statuses.where(value: :student).first.try :account
      when :former_student
        unless owner.present?
          self.owner = self.local_statuses.where(value: :former_student).first.try :account
        end
      else
        unless self.owner.present?
          self.owner = lists.first.account unless lists.empty?
        end
    end

    # Callbacks arent called when mass-assigning nested models.
    # Iterate over the contact_attributes and set the owner.
    # TODO cascade_callbacks should make this un-necessary
    if self.owner.present?
      contact_attributes.each { |att| att.account = owner unless att.account.present? }
    end
  end

  def update_lists
    # always include contacts in owner's base_list
    if self.owner && !self.lists.map(&:account).include?(self.owner)
      self.lists << self.owner.base_list
    end
  end

  def update_normalized_attributes
    self.normalized_first_name = self.first_name.try :parameterize
    self.normalized_last_name = self.last_name.try :parameterize
  end

  def set_status
    distinct_statuses = local_statuses.distinct(:value)
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
            public: true,
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
      %W(level status global_teacher_username in_professional_training).each do |att|
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
end
