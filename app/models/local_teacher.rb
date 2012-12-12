class LocalTeacher < LocalUniqueAttribute
  include AccountNameAccessor

  alias_attribute :teacher_username, :value
  after_save :keep_history_of_changes

  private
  def keep_history_of_changes
    return if self.contact.try(:skip_history_entries)
    if self.teacher_username_changed? && !self.contact.nil?
      self.contact.history_entries.create(
          attribute: "local_teacher_for_#{self.account_name}",
          changed_at: Time.zone.now.to_time,
          old_value: self.changes['value'][0])
    end
  end
end
