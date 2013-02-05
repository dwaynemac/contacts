class HomeToPersonal
	def update_email_attributes()
		Contact.all.each do |c|
			c.emails.where(:category => "home").each do |em|
				em.category = "personal"
				em.save
			end
		end
	end
end
