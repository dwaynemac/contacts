module LocaleForAccount

  DEFAULT_LOCALE = 'pt-BR'

  def locale_for(account_name)
    locale = nil
    tries = 3
    while tries > 0 && locale.nil? do
      locale = PadmaAccount.find(account_name).try(:locale)
      tries -= 1
    end
    if locale.nil?
      locale = DEFAULT_LOCALE
    end
    locale
  end

end
