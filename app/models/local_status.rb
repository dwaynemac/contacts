class LocalStatus
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :contact

  field :status, type: Symbol
  validate :student_at_one_account_only

  validates_uniqueness_of :account_id, :scope => :contact_id

  belongs_to :account
  validates_presence_of :account
  validates_inclusion_of :status, in: Contact::VALID_STATUSES, allow_blank: true

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

  def student_at_one_account_only
    return if contact.nil? || status.blank? || !(status == :student)

    student_at_other_account = (contact.local_statuses.where({status: :student}).count > 1) # this count includes current

    self.errors.add(:status,I18n.t('local_status.errors.already_student_at_other_account')) if student_at_other_account
  end
end
