class ContactsMailer < ActionMailer::Base
  default from: "padma@metododerose.org"

  def alert_failure
    mail(to: "padma@metododerose.org", subject: "Fallo el sync")
  end
end
