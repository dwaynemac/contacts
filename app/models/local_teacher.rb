class LocalTeacher < LocalUniqueAttribute
  include AccountNameAccessor

  alias_attribute :teacher_username, :value
  after_save :keep_history_of_changes

  after_save :post_activity_stream, unless: :skip_post_activity_stream
  attr_accessor :skip_post_activity_stream

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

  def post_activity_stream
    return if self.contact.try(:skip_history_entries)
    if self.teacher_username_changed? && !self.contact.nil?
      activity_username = self.contact.try(:request_username) || 'system'
      activity_account  = account_name
      a = ActivityStream::Activity.new(
          username: activity_username,
          account_name: activity_account,
          content: "novo instrutor: #{value}",
          generator: 'contacts',
          verb: 'updated',
          target_id: self.contact.id, target_type: 'Contact',
          object_id: self.contact.id, object_type: 'Contact',
          public: false
      )
      a.create(username: activity_username, account_name: activity_account)
    end
  end
end
