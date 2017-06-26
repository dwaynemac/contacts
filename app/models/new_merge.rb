# encoding: UTF-8
#
# @restful_api v0
#
# @property [String] father_id
# @property [String] son_id
class NewMerge < ActiveRecord::Base
  self.table_name = "merges"

  belongs_to :father, class_name: 'NewContact'
  belongs_to :son, class_name: 'NewContact'

  belongs_to :first_contact, class_name: 'NewContact'
  belongs_to :second_contact, class_name: 'NewContact'

  has_objectid_columns :father_id, :son_id, :first_contact_id, :second_contact_id

  SERVICES = {
    'contacts' => false,
    'crm' => false,
    'activity_stream' => false,
    'planning' => false,
    'fnz' => false,
    'mailing' => false,
    'attendance' => false
  }

  serialize :services, Hash
  serialize :warnings, Hash
  serialize :messages, Hash

  validates :first_contact_id, presence: true
  validates :second_contact_id, presence: true
  validate :similarity_of_contacts
  validate :uniqueness, on: :create

  after_save :look_for_warnings
  before_create :initialize_services
  after_validation :choose_father
  

  # Public methods:
  #
  # Start: Starts or continue with merging process.
  # @method start
  #
  # Stop: Stop with merging process.
  #   If merging process is finished this will
  #   update state to :merged otherwise it will be
  #   updated to :pending
  # @method stop

  state_machine :initial => :embryonic do
    after_transition [:ready, :pending] => :merging, :do => :merge
    after_transition :merging => :merged, :do => :destroy_son

    event :confirm do
      transition [:pending_confirmation] => :ready, :if => lambda {|merge| merge.father_has_been_chosen? }
    end

    event :start do
      transition [:ready, :pending] => :merging
    end

    event :stop do
      transition :merging => :merged, :if => lambda {|merge| merge.finished? }
      transition :merging => :pending
    end

    # To avoid maliciuos usage :embryonic => :ready only happens when
    # father has been chosen
    event :merge_initialization_finished do
      transition :embryonic => :pending_confirmation, :if => lambda {|merge| merge.has_warnings? }
      transition :embryonic => :ready, :if => lambda {|merge| merge.father_has_been_chosen? }
    end
  end

  def get_father
    if father_has_been_chosen?
      self.father
    end
  end

  def get_son
    if father_has_been_chosen?
      self.son
    end
  end

  def has_warnings?
    return false if self.warnings.size == 0
    return true
  end

  # updates value of service
  #
  # in state transitions this is used to to update #services because simple assignment doesn't persist
  #
  # @param service_name [String]
  # @param new_value [True, False]
  # @return [True, False]
  def update_service(service_name, new_value)
    self.services[service_name.to_s] = new_value
    self.update_attribute :services, self.services
  end

  #
  # in state transitions this is used to to update #messages because simple assignment doesn't persist
  #
  def update_message(message_key, message)
    self.messages[message_key.to_s] = message
    self.update_attribute :messages, self.messages
  end

  def finished?
    self.services.select{|service, finished| not finished }.count == 0
  end

  def father_has_been_chosen?
    self.father_id
  end

  private

  def initialize_services
    SERVICES.each do |name, finished|
      services[name] = finished
    end
  end

  def merge
    begin
      contacts_service_merge(father, son) unless self.services['contacts']
      crm_service_merge(father, son) unless self.services['crm']
      activity_stream_service_merge(father,son) unless self.services['activity_stream']
      planning_service_merge(father,son) unless self.services['planning']
      fnz_service_merge(father,son) unless self.services['fnz']
      mailing_service_merge(father,son) unless self.services['mailing']
      attendance_service_merge(father,son) unless self.services['attendance']
    ensure
      self.stop
    end
  end

  def destroy_son
    if finished?
      son.destroy
    end
  end

  def contacts_service_merge(father, son)

    # Contact Attributes
    son.contact_attributes.each do |ca|
      father.contact_attributes << ca.clone
    end

    # Father's Level remains
    # Father's Global Teacher remains

    # Local Teachers & Local Statuses
    son.account_contacts.each do |s_ac|
      if father.account_contacts.where(:account_id => s_ac.account_id).count == 0
        father.account_contacts << s_ac
      end
    end

    # Names
    StringAttribute.new(:category => "old_first_name", :value => son.first_name, :account => father.owner, :public => true, :contact_id => father.id )
    StringAttribute.new(:category => "old_last_name", :value => son.last_name, :account => father.owner, :public => true, :contact_id => father.id )

    # #Avatar
    # if father.avatar_url.nil?
    #   father.avatar = son.avatar
    # elsif !son.avatar_url.nil?
    #   if Rails.env == 'test'
    #     son_avatar_file = open(son.avatar.path)
    #   else
    #     son_avatar_file = open(son.avatar.url) 
    #   end
    #   father.attachments << Attachment.new(file: son_avatar_file, name: son[:avatar])
    # end

    # First enrollment date
    if father.first_enrolled_on.blank?
      father.first_enrolled_on = son.first_enrolled_on
    elsif son.first_enrolled_on && ( son.first_enrolled_on < father.first_enrolled_on )
      father.first_enrolled_on = son.first_enrolled_on
    end

    son.contact_attributes.delete_all
    father.save

    self.update_service('contacts', true)
  end

  def crm_service_merge(father, son)
    crm_merge = CrmMerge.new(:parent_id => father.id, :son_id => son.id)
    res = crm_merge.create
    case res
      when true
        self.update_service('crm', true)
      when false
        self.update_message :crm_service, I18n.t('errors.merge.services.merge_failed')
      when nil
        self.update_message :crm_service, I18n.t('errors.merge.services.connection_failed')
    end
    res
  end

  def planning_service_merge(father,son)
    planning_merge = PlanningMerge.new(father_id: father.id, son_id: son.id)
    res = planning_merge.create
    case res
      when true
        self.update_service('planning', true)
      when false
        self.update_message :planning_service, I18n.t('errors.merge.services.merge_failed')
      when nil
        self.update_message :planning_service, I18n.t('errors.merge.services.connection_failed')
    end
    res
  end

  def fnz_service_merge(father,son)
    fnz_merge = FnzMerge.new(father_id: father.id, son_id: son.id)
    res = fnz_merge.create
    case res
      when true
        self.update_service('fnz', true)
      when false
        self.update_message :fnz_service, I18n.t('errors.merge.services.merge_failed')
      when nil
        self.update_message :fnz_service, I18n.t('errors.merge.services.connection_failed')
    end
    res
  end

  def mailing_service_merge(father,son)
    mailing_merge = MailingMerge.new(parent_id: father.id, son_id: son.id)
    res = mailing_merge.create
    case res
      when true
        self.update_service('mailing', true)
      when false
        self.update_message :mailing_service, I18n.t('errors.merge.services.merge_failed')
      when nil
        self.update_message :mailing_service, I18n.t('errors.merge.services.connection_failed')
    end
    res
  end

  def attendance_service_merge(father,son)
    attendance_merge = AttendanceMerge.new(father_id: father.id, son_id: son.id)
    res = attendance_merge.create
    case res
      when true
        self.update_service('attendance', true)
      when false
        self.update_message :attendance_service, I18n.t('errors.merge.services.merge_failed')
      when nil
        self.update_message :attendance_service, I18n.t('errors.merge.services.connection_failed')
    end
    res
  end

  def activity_stream_service_merge(father,son)
    am = ActivityStream::Merge.new(parent_id: father.id, son_id: son.id)
    res = am.create
    case res
      when true
        self.update_service 'activity_stream', true
      when false
        self.update_message :activity_stream_service, I18n.t('errors.merge.services.merge_failed')
      when nil
        self.update_message :activity_stream_service, I18n.t('errors.merge.services.connection_failed')
    end
    res
  end

  # Validate existence and similarity of contacts.
  def similarity_of_contacts
    return if self.finished?
    if self.try(:first_contact).nil? || self.try(:second_contact).nil?
      self.errors[:existence_of_contacts] << I18n.t('errors.merge.existence_of_contacts')
    else
      if !first_contact.similar.include?(second_contact)
        self.errors[:similarity_of_contacts] << I18n.t('errors.merge.similarity_of_contacts')
      end
    end
  end
  
  def uniqueness
    if (NewMerge.where(first_contact_id: self.first_contact_id, second_contact_id: self.second_contact_id).exists? ||
        NewMerge.where(first_contact_id: self.second_contact_id, second_contact_id: self.first_contact_id).exists?)
      self.errors[:uniqueness] << I18n.t('errors.merge.uniqueness')
    end
  end

  # Choose father following this set of rules:
  # 1) If status is different choose the one which takes precedence
  # 2) If status is the same choose the one with more contact attributes
  # 3) If both have the same amount of contact attributes choose the lastly updated
  def choose_father
    return false if first_contact.nil? || second_contact.nil?

    if self.errors.include?(:existence_of_contacts) || self.errors.include?(:similarity_of_contacts)
      return false
    end

    self.father_id= nil
    self.son_id = nil

    set_father_by_status
    if self.father_id.nil?
      set_father_by_contact_attributes_count
    end
    if self.father_id.nil?
      set_father_by_updated_at
    end
  end

  def set_father_by_status
    if first_contact.status.nil? && second_contact.status.present?
      set_father_and_son! :second_contact
    elsif second_contact.status.nil? && first_contact.status.present?
      set_father_and_son! :first_contact
    elsif first_contact.status.present? && second_contact.status.present?
      if first_contact.status != second_contact.status
        if Contact::VALID_STATUSES.index(first_contact.status) < Contact::VALID_STATUSES.index(second_contact.status)
          set_father_and_son! :first_contact
        else
          set_father_and_son! :second_contact
        end
      end
    end
  end

  def set_father_by_contact_attributes_count
    first_count = first_contact.contact_attributes.count
    second_count = second_contact.contact_attributes.count
    if first_count != second_count
      if first_count > second_count
        set_father_and_son!(:first_contact)
      else
        set_father_and_son!(:second_contact)
      end
    end
  end

  def set_father_by_updated_at
    if first_contact.updated_at > second_contact.updated_at
      set_father_and_son! :first_contact
    else
      set_father_and_son! :second_contact
    end
  end

  # Sets #father to new_father and son to the other contact.
  # @argument new_father [Symbol] valid values: :first_contact, :second_contact
  # @raise if new_father is invalid it raises ArgumentError
  def set_father_and_son!(new_father)
    case new_father
      when :first_contact
        self.father_id = self.first_contact.id
        self.son_id = self.second_contact.id
      when :second_contact
        self.father_id = self.second_contact.id
        self.son_id = self.first_contact.id
      else
        raise ArgumentError
    end
  end

  def look_for_warnings
    return unless father_has_been_chosen?

    # Local Status
    # For each local status that they share (:account_id) warn the user
    # if the son has the local_status that takes precedence
    son.account_contacts.each do |ac|
      if father.account_contacts.where(:account_id => ac.account_id).exists?
        father_ac = father.account_contacts.where(:account_id => ac.account_id).first

        father_ls_index = Contact::VALID_STATUSES.index(father_ac.local_status)
        son_ls_index = Contact::VALID_STATUSES.index(ac.local_status)

        father_ls_index = -1 if father_ls_index.nil?
        son_ls_index = -1 if son_ls_index.nil?

        unless father_ls_index <= son_ls_index
          if !self.warnings.has_key?('local_statuses')
            self.warnings['local_statuses'] = Array.new
          end
          self.warnings['local_statuses'].push(ac.account_id)
        end
      end

      # warn if contacts are students in different accounts.
      if ac.local_status == "student" && !father.account_contacts.where("account_id != #{ac.account_id} AND local_status = 'student'").empty?
        if !self.warnings.has_key?('local_statuses')
          self.warnings['local_statuses'] = Array.new
        end
        self.warnings['local_statuses'].push(ac.account_id)
        self.messages['multi_student'] = I18n.t('errors.merge.student_in_multiple_accounts')
      end
    end

    # Level
    # Warn the user if the son has a higher level
    if son.level && father.level
      if NewContact::VALID_LEVELS[son.level] > NewContact::VALID_LEVELS[father.level]
        self.warnings['level'] = true
      end
    end
    self.merge_initialization_finished
  end

end
