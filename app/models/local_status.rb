class LocalStatus < LocalUniqueAttribute
  include AccountNameAccessor

  alias_attribute :status, :value

  validate :student_at_one_account_only

  before_validation :value_to_sym
  validates_inclusion_of :value, in: Contact::VALID_STATUSES, allow_blank: true

  after_save :keep_history_of_changes

  private

  def value_to_sym
    unless self.value.nil? || self.value.is_a?(Symbol)
      self.value = self.value.to_sym
    end
    return true # continue
  end

  # A contact can have :student status in only one account
  def student_at_one_account_only
    return if contact.nil? || value.blank? || !(value == :student)

    student_at_other_account = (contact.local_statuses.where({value: :student}).count > 1) # this count includes current

    self.errors.add(:value,I18n.t('local_status.errors.already_student_at_other_account')) if student_at_other_account
  end

  def keep_history_of_changes
    if self.status_changed? && self.contact.present?
      self.contact.history_entries.create(
        attribute: "local_status_for_#{self.account_name}",
        changed_at: Time.zone.now.to_time,
        old_value: self.changes['value'][0])
    end
  end
end
