class ImageAttachment < ContactAttribute

  field :image
  mount_uploader :image, ImageUploader

end
