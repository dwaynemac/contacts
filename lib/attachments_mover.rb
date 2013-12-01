require 'open-uri'

class AttachmentsMover

  def initialize
  end
  
  def refactor_attachments_location
    copy_contacts_attachments_to_ordered_folder
    return nil
  end

  # if attachments were saved unordered, in uploads folder, store them in the storage_dir
  # defined in attachment_uploader
  def copy_contacts_attachments_to_ordered_folder
    contacts = Contact.where(:attachments.exists => true)
    contacts.each do |contact|
      # get every attachment of the contact
      contact.attachments.each do |att|
        # if the file does not exist
        unless file_exists?(att.file.url)
          # copy in ordered folder
          host = get_attachment_host(att)
          file_name = att.file.path.split("/").last
          file_url = host+'uploads/'+"#{file_name}"

          File.open(file_name, 'wb') do |tmp_file|
            tmp_file << open(file_url).read
            new_att = contact.attachments.new(name: att.name,
                                              description: att.description,
                                              public: att.public,
                                              file: tmp_file)
            new_att._type = "Attachment"
            new_att.account = contact.owner
            new_att.save
          end

          att.destroy
        end
      end
    end
  end


  def file_exists? (url)
    response = false
    begin
      file = open(url)
      response = true
    rescue
      # nothing
    ensure
      file.close unless file.nil?
    end

    response
  end

  def get_attachment_host(att)
    host = att.file.url
    host.slice! att.file.path

    return host
  end
end