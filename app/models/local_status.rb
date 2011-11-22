class LocalStatus
  include Mongoid::Document
  include Mongoid::Timestamps

  embedded_in :contact

  field :status, type: Symbol
  validate :student_at_one_account_only

  validates_uniqueness_of :account_id, :scope => :contact_id

  belongs_to :account
  validates_presence_of :account
  validates_inclusion_of :status, in: [:student, :former_student, :prospect], allow_blank: true

  private

  def student_at_one_account_only
    return if contact.nil?
    return if status.blank?
    return unless status == :student

    student_at_other_account = (contact.local_statuses.where({status: :student}).count > 0)

    self.errors.add(:status,I18n.t('local_status.errors.already_student_at_other_account')) if student_at_other_account
  end
end
