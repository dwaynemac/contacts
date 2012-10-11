# encoding: UTF-8

class Merge
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :father, class_name: 'Contact'
  belongs_to :son, class_name: 'Contact'

  belongs_to :first_contact, class_name: 'Contact'
  belongs_to :second_contact, class_name: 'Contact'

  SERVICES = {
    'contacts' => false,
    'crm' => false,
    'activity_stream' => false
  }

  field :services, :type => Hash, :default => SERVICES
  field :warnings, :type => Hash, :default => {}

  validates :first_contact_id, presence: true
  validates :second_contact_id, presence: true
  validate :similarity_of_contacts

  after_validation :choose_father
  after_save :look_for_warnings

  # Public methods:
  #
  # Start: Starts or continue with merging process.
  # @method start
  #
  # Stop: Stop with merging process.
  #   If merging process is finished this will
  #   update state to :merge otherwise it will be
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
  # @param service_name [String]
  # @param new_value [True, False]
  # @return [True, False]
  def update_service(service_name, new_value)
    self.services[service_name.to_s] = new_value
    self.update_attribute :services, self.services
  end

  def finished?
    self.services.select{|service, finished| not finished }.count == 0
  end

  def father_has_been_chosen?
    self.father_id
  end

  private

  def merge
    begin
      contacts_service_merge(father, son) unless self.services['contacts']
      crm_service_merge(father, son) unless self.services['crm']
      activity_stream_service_merge(father,son) unless self.services['activity_stream']
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

    # Local Teachers
    son.local_teachers.each do |lt|
      if father.local_teachers.where(:account_id => lt.account_id).count == 0
        father.local_unique_attributes << lt
      end
    end

    # Local Statuses
    son.local_statuses.each do |ls|
      if father.local_statuses.where(:account_id => ls.account_id).count == 0
        father.local_unique_attributes << ls
      end
    end

    # Lists
    father.lists << son.lists

    # Names
    father.contact_attributes << CustomAttribute.new(:name => "old_first_name", :value => son.first_name, :account => father.owner, :public => true )
    father.contact_attributes << CustomAttribute.new(:name => "old_last_name", :value => son.last_name, :account => father.owner, :public => true )

    son.contact_attributes.delete_all
    father.save

    self.update_service('contacts', true)
  end

  def crm_service_merge(father, son)
    crm_merge = CrmMerge.new(:parent_id => father.id, :son_id => son.id)
    if crm_merge.create
      self.update_service('crm', true)
    end
  end

  def activity_stream_service_merge(father,son)
    am = ActivityStream::Merge.new(parent_id: father._id.to_s, son_id: son._id.to_s)
    if am.create
      self.update_service 'activity_stream', true
    end
  end

  # Validate existence and similarity of contacts.
  def similarity_of_contacts
    if !Contact.where(:_id => self.first_contact_id).exists? || !Contact.where(:_id => self.second_contact_id).exists?
      self.errors[:existence_of_contacts] << I18n.t('errors.merge.existence_of_contacts')
    else
      if !first_contact.similar.include?(second_contact)
        self.errors[:similarity_of_contacts] << I18n.t('errors.merge.similarity_of_contacts')
      end
    end
  end

  # Choose father following this set of rules:
  # 1) If status is different choose the one which takes precedence
  # 2) If status is the same choose the one with more contact attributes
  # 3) If both have the same amount of contact attributes choose the lastly updated
  def choose_father

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
        self.father = self.first_contact
        self.son = self.second_contact
      when :second_contact
        self.father = self.second_contact
        self.son = self.first_contact
      else
        raise ArgumentError
    end
  end

  def look_for_warnings
    return unless father_has_been_chosen?

    # Local Status
    # For each local status that they share (:account_id) warn the user
    # if the son has the local_status that takes precedence
    son.local_statuses.each do |ls|
      if father.local_statuses.where(:account_id => ls.account_id).exists?
        father_ls = father.local_statuses.where(:account_id => ls.account_id).first

        father_ls_index = Contact::VALID_STATUSES.index(father_ls.value)
        son_ls_index = Contact::VALID_STATUSES.index(ls.value)

        father_ls_index = -1 if father_ls_index.nil?
        son_ls_index = -1 if son_ls_index.nil?

        unless father_ls_index <= son_ls_index
          if !self.warnings.has_key?('local_statuses')
            self.warnings['local_statuses'] = Array.new
          end
          self.warnings['local_statuses'].push(ls.account_id)
        end
      end
    end

    # Level
    # Warn the user if the son has a higher level
    if son.level && father.level
      if Contact::VALID_LEVELS[son.level] > Contact::VALID_LEVELS[father.level]
        self.warnings['level'] = true
      end
    end
    self.merge_initialization_finished
  end

end
