# encoding: UTF-8
require 'mongoid/criteria'

class Contact
  include Mongoid::Document
  include Mongoid::Timestamps

  include Mongoid::Search
  search_in :first_name, :last_name, {:contact_attributes => :value }, {:ignore_list => Rails.root.join("config", "search_ignore_list.yml"), :match => :all}

  embeds_many :contact_attributes, :validate => true, :cascade_callbacks => true
  validates_associated :contact_attributes
  accepts_nested_attributes_for :contact_attributes, :allow_destroy => true

  embeds_many :local_unique_attributes, validate: true, cascade_callbacks: true
  validates_associated :local_unique_attributes
  accepts_nested_attributes_for :local_unique_attributes, allow_destroy: true

  has_many :history_entries, as: 'historiable', dependent: :delete
  after_save :keep_history_of_changes

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
  before_validation :set_status
  validates_inclusion_of :status, :in => VALID_STATUSES, :allow_blank => true

  belongs_to :owner, :class_name => "Account"
  before_validation :assign_owner

  field :global_teacher_username, type: String
  before_validation :set_global_teacher

  references_and_referenced_in_many :lists
  before_save :update_lists

  validates :first_name, :presence => true

  attr_accessor :check_duplicates
  validate :validate_duplicates, :if => :check_duplicates

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
  # param s [String]
  def level=(s)
    write_attribute(:level, VALID_LEVELS[s])
  end

  # defines Contact#emails/telephones/addresses/custom_attributes/etc
  # they all return a Criteria scoping to according _type
  %W(email telephone address custom_attribute date_attribute identification).each do |k|
    delegate k.pluralize, to: :contact_attributes
  end

  # @return [Array<Telephone>] mobile telephones embedded in this contact
  def mobiles
    self.contact_attributes.telephones.mobiles
  end

  # defines Contact#coefficients/...
  # they all return a Criteria scoping to according _type
  %W(coefficient local_status local_teacher).each do |lua|
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

  # @method xxx_for_yyy=(value)
  # @param value
  # Sets xxx local_unique_attribute on account_id yyy with value :value
  # @example Contact#coefficient_for_belgrano=Coefficient::PMENOS
  def method_missing(method_sym, *arguments, &block)

    # local_unique_attribute reader for an account_id
    if method_sym.to_s =~ /^(.+)_for_([^=]+)$/
      a = Account.where(name: $2).first
      if a.nil?
        return nil
      else
        return self.local_unique_attributes.where(:account_id => a._id, '_type' => $1.camelcase).first.try :value
      end

    # local_unique_attribute setter for an account_name
    elsif method_sym.to_s =~ /^(.+)_for_(.+)=$/
      a = Account.where(name: $2).first
      if a.nil?
        raise 'account_id not found'
      else
        lua = self.local_unique_attributes.where(:account_id => a._id, '_type' => $1.camelcase).first
        if lua.nil?
          self.local_unique_attributes << $1.camelcase.constantize.new(account: a, value: arguments.first)
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
  def as_json(options = nil)
    options ||= {}

    account = options[:account]
    if account
      # add these options when account_id specified
      options = options.merge({:except => [:contact_attributes, :local_unique_attributes]})
    end

    options = options.merge({:except => :owner_id, :methods => [:owner_name, :local_statuses, :coefficients_counts]})

    json = super options

    if account
      # add these data when account_id specified
      json[:contact_attributes] = self.contact_attributes.for_account(account, options)
      %w{local_status coefficient local_teacher}.each do |local_attribute|
        json[local_attribute] = self.send("#{local_attribute}_for_#{account.name}")
      end
      json[:linked] = self.linked_to?(account)
      json[:last_local_status] = self.history_entries.last_value("local_status_for_#{account.name}".to_sym)
    end
    json
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

    unless self.last_name.blank?
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
            value: identification.value.gsub(/[\.\-_\s\/]/,'')
        }})
      end
    end

    if self.id.present?
      contacts = contacts.excludes(:id => self.id)
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
            else
              "#{attr} #{obj.send(attr)} #{messages.join(', ')}"
            end
          end.flatten
        end
      end
    end

    error_messages
  end

  # This is same as #where but will make some transformations on selector.
  # All first level value will be converted to Regular expressions
  #
  # @param selector   [ Hash ]      query
  # @param account_id    [ BSON / String ] account id with wich to interpret local attributes
  # @option selector :telephone, searches within all telephones
  # @option selector :email, searches within all emails
  # @option selector :address
  # @option selector :custom_attribute
  # @option selector :local_status      only considered if account_id is specified
  # @option selector :local_teacher      only considered if account_id is specified
  # @option selector :birth_day
  #
  # @return [Mongoid::Criteria]
  def self.api_where(selector = nil, account_id = nil)
    return self if selector.nil?

    new_selector = {'$and' => []}

    selector.each do |k,v|
      unless v.blank?
        case k.to_s
          when 'telephone', 'email', 'address', 'custom_attribute'
            new_selector['$and'] << {
              :contact_attributes => { '$elemMatch' => { "_type" => k.to_s.camelize, "value" => Regexp.new(v.to_s,Regexp::IGNORECASE)}}
            }
          when 'country', 'state', 'city', 'postal_code'
            new_selector['$and'] << {:contact_attributes => { '$elemMatch' => { "_type" => "Address", k => Regexp.new(v.to_s)}}}
          when 'contact_attributes'
            new_selector['$and'] << {k => v}
          when 'date_attributes'
            v.each do |sv|
              aux = DateAttribute.convert_selector(sv)
              new_selector['$and'] << aux unless aux.nil?
            end
          when 'date_attribute'
            aux = DateAttribute.convert_selector(v)
            new_selector['$and'] << aux unless aux.nil?
          when 'local_status', 'coefficient', 'local_teacher'
            if account_id.present?
              new_selector[:local_unique_attributes] = {'$elemMatch' => {_type: k.to_s.camelcase, value: v, account_id: account_id}}
            end
          when 'level'
            new_selector['$and'] << {:level => VALID_LEVELS[v]}
          when /^(.+)_for_([^=]+)$/
            local_attribute = $1
            account_name    = $2
            a = Account.where(name: account_name).first
            if a
              new_selector['$and'] << {
                :local_unique_attributes => {'$elemMatch' => {_type: local_attribute.to_s.camelcase, value: v, account_id: a.id}}
              }
            end
          else
            new_selector[k] = v.is_a?(String)? Regexp.new(v,Regexp::IGNORECASE) : v
        end
      end
    end

    if new_selector['$and'].empty?
      new_selector.delete('$and')
    elsif new_selector['$and'].size == 1
      aux = new_selector.delete('$and')[0]
      new_selector = new_selector.merge(aux)
    end

    where(new_selector)
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

  def keep_history_of_changes
    # level, global_status and teacher_username
    %W(level status global_teacher_username).each do |att|
      if self.send("#{att}_changed?")
        self.history_entries.create(attribute: att,
                                    changed_at: Time.zone.now.to_time,
                                    old_value: self.changes[att][0])
      end
    end
    # local_status changes are tracked in LocalStatus model
    # local_teacher changes are tracked in LocalTeacher model
  end

  def validate_duplicates
    duplicates = self.similar
    unless duplicates.empty?
      self.errors[:duplicates] << I18n.t('errors.messages.could_have_duplicates')
      self.errors[:possible_duplicates] = duplicates.map {|c| c.minimum_representation}
    end
  end

end
