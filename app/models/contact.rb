# encoding: UTF-8
require 'mongoid/criteria'

class Contact
  include Mongoid::Document
  include Mongoid::Timestamps
  #include Mongoid::Versioning

  include Mongoid::Search

  accepts_nested_attributes_for :contact_attributes

  embeds_many :contact_attributes, :validate => true, :cascade_callbacks => true

  has_many :history_entries, as: 'historiable', dependent: :delete
  after_save :keep_history_of_changes

  field :first_name
  field :last_name

  field :normalized_first_name
  field :normalized_last_name
  before_save :update_normalized_attributes

=begin
  TODO study better what this does
  # run rake db:mongoid:create_indexes to create these indexes
  index(
    [
      [ :normalized_first_name, Mongo::ASCENDING ],
      [ :normalized_last_name, Mongo::ASCENDING ]
    ],
    background: true
  )
=end

  field :gender
  validates_inclusion_of :gender, in: %W(male female), allow_blank: true

  field :avatar
  mount_uploader :avatar, AvatarUploader


  VALID_LEVELS = %W(aspirante sádhaka yôgin chêla graduado asistente docente maestro) # ordered by hierarchy (last is higher)
  field :level, :type => String

  VALID_STATUSES = [:student, :former_student, :prospect] # they are ordered by precedence (first has precedence)
  field :status, type: Symbol
  before_validation :set_status
  validates_inclusion_of :status, :in => VALID_STATUSES, :allow_blank => true

  embeds_many :local_statuses, :validate => true, :cascade_callbacks => true
  accepts_nested_attributes_for :local_statuses, :allow_destroy => true

  belongs_to :owner, :class_name => "Account"
  before_validation :assign_owner

  references_and_referenced_in_many :lists
  before_save :update_lists

  validates :first_name, :presence => true

  validates_associated :contact_attributes

  accepts_nested_attributes_for :contact_attributes, :allow_destroy => true

  attr_accessor :check_duplicates
  validate :validate_duplicates, :if => :check_duplicates

  # @return [String]
  def full_name
    "#{first_name} #{last_name}"
  end

  # defines Contact#emails/telephones/addresses/custom_attributes/etc
  # they all return a Criteria scoping to according _type
  %W(email telephone address custom_attribute date_attribute).each do |k|
    define_method(k.pluralize) { self.contact_attributes.where(_type: k.camelcase) }
  end

  # @return [Array<Telephone>] mobile telephones embedded in this contact
  def mobiles
    self.contact_attributes.where(
      "_type" => "Telephone",
      "category" => "Mobile"
    )
  end

  # Setter for local_status of a certain account
  # This allows a cleaner API for update /accounts/account_id/contacts usage
  # @author Dwayne Macgowan
  # @param [Hash] options
  # @option options [String] :account_id
  # @option options [Symbol] :status this should be a valid status
  # @raise [ArgumentError] if :account_id is not given
  #
  # @example @contact.local_status = account_id: acc.id, status: :student
  #
  # @example
  #   params[:contact][:local_status] = {:account_id => @account.id, :status => params[:contact].delete(:local_status)}
  #   @contact.update_attributes(params[:contact])
  #
  # @return [LocalStatus]
  def local_status=(options)
    return unless options.is_a?(Hash)
    ls = self.local_statuses.where(:account_id => options[:account_id]).first
    if ls.nil?
      self.local_statuses.new(account_id: options[:account_id], status: options[:status])
    else
      ls.status = options[:status]
    end
    ls
  end

  # TODO define logical attribute #local_status_for_#{account_name} using method missing


  # @param [Hash] options
  # @option options [Account] account
  # @option options [TrueClass] include_masked
  def as_json(options={})
    options={} if options.nil? # default set in method definition seems not to be working
    account = options.delete(:account) if options
    if account
      # add these options when account specified
      options.merge!({:except => :contact_attributes})
    end

    json = super(options.merge!({:except => :owner_id, :methods => [:owner_name]}))

    if account
      # add these data when account specified
      json[:contact_attributes] = self.contact_attributes.for_account(account, options)
      json[:local_status] = self.local_statuses.where(account_id: account._id).try(:first).try(:status)
      json[:linked] = self.linked_to?(account)
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

  search_in :first_name, :last_name, {:contact_attributes => :value }, {:ignore_list => Rails.root.join("config", "search_ignore_list.yml")}

  def update_status!
    self.set_status
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
          'category' => /Mobile/i,
          'value' => mobile
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


    if error_messages[:contact_attributes]
      error_messages[:contact_attributes] = self.contact_attributes.reject(&:valid?).map do |c_attr|
        c_attr.errors.messages.map do |k,v|
          if k == :value
            "#{c_attr.value} #{v.join(', ')}"
          else
            "#{k} #{c_attr.send(k)} #{v.join(', ')}"
          end
        end.flatten
      end
    end

    error_messages
  end

  # This is same as #where but will make some transformations on selector.
  # All first level value will be converted to Regular expressions
  #
  # @param [Hash] selector
  # @option selector :telephone
  # @option selector :email
  # @option selector :address
  # @option selector :custom_attribute
  # @option selector :local_status
  # @option selector :birth_day
  #
  # @return [Mongoid::Criteria]
  def self.api_where(selector = nil)
    return self if selector.nil?

    new_selector = {'$and' => []}

    selector.each do |k,v|
      if v.blank?
        # skip blanks
      elsif k.to_s.in?(%W(telephone email address custom_attribute))
        new_selector['$and'] << {:contact_attributes => { '$elemMatch' => { "_type" => k.to_s.camelize, "value" => Regexp.new(v.to_s)}}}
      elsif k.to_s == 'contact_attributes'
        new_selector['$and'] << {k => v}
      elsif k.to_s == 'birth_day'
        v = {day: v.day, month: v.month, year: v.year} if v.is_a?(Date)

        %W(day month year).each{|k|v.delete(k) if v[k].blank?}
        v = v.merge({'_type' => 'DateAttribute',category: 'birth_day'})

        new_selector['$and'] << {:contact_attributes => {'$elemMatch' => v}}
      elsif k.to_s == 'local_status' && @account.present?
        # Service Consumer asks for local_status but we must map this to HIS local_status
        new_selector[:local_statuses] = { '$elemMatch' => {account_id: @account.id, status: v}}
      elsif v.is_a?(String)
        new_selector[k] = Regexp.new(v)
      else
        new_selector[k] = v
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
        self.owner = self.local_statuses.where(status: :student).first.try :account
      when :former_student
        unless owner.present?
          self.owner = self.local_statuses.where(status: :former_student).first.try :account
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
    distinct_statuses = local_statuses.distinct(:status)
    # order of VALID_STATUSES is important
    VALID_STATUSES.each do |s|
      if distinct_statuses.include?(s)
        self.status = s
        break
      end
    end
  end

  def keep_history_of_changes
    # level and global_status
    %W(level status).each do |att|
      if self.send("#{att}_changed?")
        self.history_entries.create(attribute: att,
                                    changed_at: Time.zone.now.to_time,
                                    old_value: self.changes[att][0])
      end
    end
    # local_status are tracked in LocalStatus model
  end

  def validate_duplicates
    duplicates = self.similar
    unless duplicates.empty?
      self.errors[:duplicates] << I18n.t('errors.messages.could_have_duplicates')
      self.errors[:possible_duplicates] = duplicates.map {|c| c.minimum_representation}
    end
  end
end