task :set_first_enrolled_on => :environment do
  Contact.where(status: 'student', first_enrolled_on: nil).each do |c|
    enrollments = Enrollment.paginate(contact_id: c.id, per_page: 9999)
    if enrollments
      c.update_attribute :first_enrolled_on, enrollments.first.try(:changed_at)
    end
  end
end
