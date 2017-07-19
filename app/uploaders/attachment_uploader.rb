# encoding: utf-8

class AttachmentUploader < CarrierWave::Uploader::Base

  # RMagick needs imagemagick installed on the computer, almost always available in Unix systems
  # It also needs this package: "sudo apt-get install libmagick9-dev"
  include CarrierWave::RMagick
  include CarrierWave::MimeTypes

  process :set_content_type

  def store_dir
    "uploads/attachment/#{mounted_as}/#{model.id}"
  end

  version :mini, :if => :image? do
    process :resize_to_fill => [50,50]
  end

  version :thumb, :if => :image? do
    process :resize_to_fit => [200, 200]
  end

  protected
    def image?(new_file)
      new_file.content_type.start_with? 'image'
    end

end
