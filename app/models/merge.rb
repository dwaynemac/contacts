# encoding: UTF-8

class Merge
  include Mongoid::Document
  include Mongoid::Timestamps

  field :father_id

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

    event :confirm do
      transition [:pending_confirmation] => :ready, :if => :father_has_been_chosen?
    end

    event :start do
      transition [:ready, :pending] => :merging
    end

    event :stop do
      transition :merging => :merged, :if => :finished?
      transition :merging => :pending
    end

    # To avoid maliciuos usage :embryonic => :ready only happens when
    # father has been chosen
    event :merge_initialization_finished do
      transition :embryonic => :pending_confirmation, :if => :has_warnings?
      transition :embryonic => :ready, :if => :father_has_been_chosen?
    end
  end

  # private keyword should be put here

  def get_father
    if father_has_been_chosen?
      Contact.find(self.father_id)
    end
  end

  def get_son
    if father_has_been_chosen?
      if self.first_contact_id != self.father_id
        return first_contact
      else
        return second_contact
      end
    end
  end

  def has_warnings?
    return false if self.warnings.size == 0
    return true
  end

  private

  def merge
    begin
      father = get_father
      son = get_son

      if !self.services['contacts']
        contacts_service_merge(father, son)
      end

      if !self.services['crm']
        crm_service_merge(father, son)
      end

      if !self.services['activity_stream']
        activity_stream_service_merge(father,son)
      end

      son.destroy if finished?

      self.stop
    rescue
      son.destroy if finished?
      self.stop
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

    father.contact_attributes << CustomAttribute.new(:name => "old_first_name", :value => son.first_name)
    father.contact_attributes << CustomAttribute.new(:name => "old_last_name", :value => son.last_name)

    son.contact_attributes.delete_all
    father.save

    self.services['contacts'] = true
  end

  def crm_service_merge(father, son)
    crm_merge = CrmMerge.new(:parent_id => father.id, :son_id => son.id)
    if crm_merge.create
      self.services['crm'] = true
    end
  end

  def activity_stream_service_merge(father,son)
    am = ActivitiesMerge.new(parent_id: father.id.to_s, son_id: son.id.to_s)
    if am.create
      self.services['activity_stream'] = true
    end
  end

  def finished?
    self.services.select{|service, finished| not finished}.count == 0
  end

  def father_has_been_chosen?
    self.father_id
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
      self.father_id = self.second_contact_id
    elsif second_contact.status.nil? && first_contact.status.present?
      self.father_id = self.first_contact_id
    elsif first_contact.status.present? && second_contact.status.present?
      if first_contact.status != second_contact.status
        if Contact::VALID_STATUSES.index(first_contact.status) < Contact::VALID_STATUSES.index(second_contact.status)
          self.father_id = self.first_contact_id
        else
          self.father_id = self.second_contact_id
        end
      end
    end
  end

  def set_father_by_contact_attributes_count
    first_count = first_contact.contact_attributes.count
    second_count = second_contact.contact_attributes.count
    if first_count != second_count
      if first_count > second_count
        self.father_id = self.first_contact_id
      else
        self.father_id = self.second_contact_id
      end
    end
  end

  def set_father_by_updated_at
    if first_contact.updated_at > second_contact.updated_at
      self.father_id = self.first_contact_id
    else
      self.father_id = self.second_contact_id
    end
  end

  def look_for_warnings
    father = get_father
    son = get_son

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

        if father_ls_index < son_ls_index
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
