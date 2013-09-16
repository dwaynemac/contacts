# encoding: utf-8

class AttachmentUploader < CarrierWave::Uploader::Base

  # RMagick needs imagemagick installed on the computer, almost always available in Unix systems
  # It also needs this package: "sudo apt-get install libmagick9-dev"
  include CarrierWave::RMagick
  include CarrierWave::MimeTypes

  version :mini, :if => :image? do
    process :resize_to_fill => [50,50]
  end

  version :thumb, :if => :image? do
    process :resize_to_fit => [200, 200]
  end

  def extension_white_list
    %w(jpg jpeg gif png csv pdf doc htm html docx)
  end

  protected
    def image?(new_file)
      new_file.content_type.start_with? 'image'
    end

end
