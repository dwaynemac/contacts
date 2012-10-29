class Attachment < ContactAttribute
  embedded_in :contact

  field :file



  mount_uploader :file, AttachmentUploader
end
