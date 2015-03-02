task :set_first_enrolled_on => :environment do
  Contact.api_where(status: 'student', first_enrolled_on: nil).find_each(batch_size: 100) do |c|
    enrollments = Enrollment.paginate(contact_id: c.id, per_page: 9999)
    if enrollments
      c.update_attribute :first_enrolled_on, enrollments.first.try(:changed_at)
    end
  end
end
