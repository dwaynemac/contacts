class ContactsMailer < ActionMailer::Base
  default from: "padma@metododerose.org"

  def alert_failure(error_message)
    @body[:error_message] = error_message
    mail(to: "padma@metododerose.org", subject: "Fallo el sync")
  end
end
