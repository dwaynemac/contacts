require 'open-uri'

class UnorderedFilesMover

  def initialize
  end
  
  def copy_unordered_files
    %w(avatar attachments).each do |field|
      copy_contacts_files_to_ordered_folder(field)
    end

    return nil
  end

  # if attachments were saved unordered, in uploads folder, store them in the storage_dir
  # defined in attachment_uploader
  def copy_contacts_files_to_ordered_folder(field)
    # get contacts that have files stored with carrierwave
    contacts = Contact.where(field.to_sym.exists => true)
    contacts.each do |contact|
      begin
        # update_avatar or update_attachment, depending on the field
        send("update_#{field}", contact)
      rescue => e
        puts "rescued exception when working on contact##{contact.id}"
        puts e.message
      end
    end
  end

  def update_avatar(contact)
    unless file_exists?(contact.avatar.url)
      # copy in ordered folder
      host = get_remote_file_host(contact.avatar)
      file_name = contact.avatar.path.split("/").last
      file_url = host+'uploads/'+"#{file_name}"

      File.open("#{Rails.root}/tmp/#{file_name}", 'wb') do |tmp_file|
        tmp_file << open(file_url).read
        contact.avatar = tmp_file
        contact.save
      end
      File.delete("#{Rails.root}/tmp/#{file_name}")
    end
  end

  def update_attachments(contact)
    # get every stored file of the contact
    contact.attachments.each do |att|
      # if the file does not exist
      unless file_exists?(att.file.url)
        # copy in ordered folder
        host = get_remote_file_host(att.file)
        file_name = att.file.path.split("/").last
        file_url = host+'uploads/'+"#{file_name}"

        File.open("#{Rails.root}/tmp/#{file_name}", 'wb') do |tmp_file|
          tmp_file << open(file_url).read
          new_att = contact.attachments.new(name: att.name,
                                            description: att.description,
                                            public: att.public,
                                            file: tmp_file)
          new_att._type = "Attachment"
          new_att.account = contact.owner
          new_att.save
        end

        File.delete("#{Rails.root}/tmp/#{file_name}")
        att.destroy
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

  def get_remote_file_host(remote_file)
    host = remote_file.url
    host.slice! remote_file.path

    return host
  end
end
