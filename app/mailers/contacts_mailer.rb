class ContactsMailer < ActionMailer::Base
  default from: "padma@metododerose.org"

  def alert_failure(account_name, error_message)
    @body[:error_message] = error_message
    @body[:account_name] = account_name
    mail(to: "padma@metododerose.org", subject: "Fallo la sincronización de MailChimp")
  end
end
