class LocalStatus
  include Mongoid::Document
  include Mongoid::Timestamps


  field :status, type: Symbol
  validate :student_at_one_account_only

  validates_uniqueness_of :account_id, :scope => :contact_id

  embedded_in :contact
  belongs_to_related :account
  validates_presence_of :account
  validates_inclusion_of :status, in: Contact::VALID_STATUSES, allow_blank: true

  after_save :keep_history_of_changes

  def account_name
    self.account.try :name
  end

  def account_name=(name)
    self.account = Account.where(name: name).first
  end

  def as_json(options)
    super({methods: :account_name, except: :account_id}.merge(options||{}))
  end

  private

  # A contact can have :student status in only one account
  def student_at_one_account_only
    return if contact.nil? || status.blank? || !(status == :student)

    student_at_other_account = (contact.local_statuses.where({status: :student}).count > 1) # this count includes current

    self.errors.add(:status,I18n.t('local_status.errors.already_student_at_other_account')) if student_at_other_account
  end

  def keep_history_of_changes

    if self.status_changed?
      self.contact.history_entries.create(
        attribute: "local_status_for_#{self.account_name}",
        changed_at: Time.zone.now.to_time,
        old_value: self.changes['status'][0])
    end
  end
end
