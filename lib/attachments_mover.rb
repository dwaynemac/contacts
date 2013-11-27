class AttachmentsMover
  
  def refactor_attachments_location
    contacts = get_contacts_with_unordered_attachments
    copy_contacts_attachments_to_ordered_folder(contacts)
  end

  def get_contacts_with_unordered_attachments
    contacts = []
    # get every contact that has an attachment
    with_attachments = Contact.where(:attachments.exists => true)
  end

  def copy_contacts_attachments_to_ordered_folder(contacts)
    contacts.each do |contact|
      # get every attachment of the contact
      contact.attachments.each do |att|
        # if the file does not exist
        unless att.file.exists?
          # copy in ordered folder
          file_url = att.file.url
          # old_file_url =
          # file =
          att.store!()
          att.recreate_versions!
        end
      end
    end
  end
end