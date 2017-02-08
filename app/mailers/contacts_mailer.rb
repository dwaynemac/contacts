# encoding: utf-8
class ContactsMailer < ActionMailer::Base
  default from: "padma@metododerose.org"

  def alert_failure(account_name, error_message)
    mail(to: "padma@metododerose.org",
         subject: "Fallo la sincronizacion de MailChimp",
         body: "El synch de Mailchimp de la cuenta #{account_name} falló por el siguiente motivo: #{error_message}." 
         )
  end
end
