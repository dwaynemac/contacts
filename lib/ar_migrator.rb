class ArMigrator

  def self.initialize()
  end

  def migrate_accounts()
    log("Migrating #{Account.count} accounts to MySQL.")
    Account.all.each do |a|
      migrate_account(a)
    end
  end

  def migrate_contacts()
    log("Migrating #{Contact.count} contacts to MySQL.")
    Contact.all.each do |c|
      migrate_contact(a)
    end
  end

  def migrate_account(account)
    log("Migrating #{account.contacts.count} contacts for #{account.name}...")

    new_account = NewAccount.find_or_create_by_name(account.name)

    if new_account.valid?
      account.contacts.each do |c|
        migrate_contact(c, new_account)
      end
    end
  end

  def migrate_contact(contact, owner = nil)
    log("Migrating #{contact.full_name}")
    
    # Find or create owner
    owner = NewAccount.find_or_create_by_name(contact.owner.name) unless owner.present?
      
    if owner.id.present?
      # Create contact
      new_contact = NewContact.new({
        first_name: contact.first_name,
        last_name: contact.last_name,
        owner_id: owner.id,
        status: contact.status
        })
      new_contact.id = contact.id
      new_contact.save

      # Migrate LUAs
      contact.local_unique_attributes.each do |lua|
        lua_account = NewAccount.find_or_create_by_name(lua.account.name)

        if lua_account.id.present?
          ac = new_contact.account_contacts.find_or_initialize_by_account_id(lua_account.id)

          case lua._type
          when "LocalStatus"
            ac.local_status = lua.value
          when "LocalTeacher"
            ac.local_teacher_username = lua.value
          # TODO: migrate rest of LUA types
          end

          ac.save
        end
      end

      #Migrate Contact attributes

    end
  end

  private

  def log(msg)
    logger.info("[ar_migrator] #{msg}")
  end

  def warn(msg)
    logger.warn("[ar_migrator] #{msg}")
  end

  ##
  # Encapsulated logger here in case we wish to change it
  # for ArMigrator
  def logger
    Rails.logger
  end
end
