# encoding: utf-8

class AvatarUploader < CarrierWave::Uploader::Base

  # Include RMagick or ImageScience support:
  # RMagick needs imagemagick installed on the computer, almost always available in Unix systems
  # It also needs this package: "sudo apt-get install libmagick9-dev"
  include CarrierWave::RMagick
  # include CarrierWave::MiniMagick
  # include CarrierWave::ImageScience

  # Choose what kind of storage to use for this uploader:
  # storage :file
  # storage :fog

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  #def store_dir
    #"images/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
    #"#{Rails.root}/tmp/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  #end

  # Provide a default URL as a default if there hasn't been a file uploaded:
  # def default_url
  #   "/images/fallback/" + [version_name, "default.png"].compact.join('_')
  # end
  #

  # Process files as they are uploaded:
  # process :scale => [200, 300]
  #
  # def scale(width, height)
  #   # do something
  # end
  #
  # Process file with auto-rotation
  # this should go before all other process steps

  def auto_orient
    manipulate! do |image|
      image.tap(&:auto_orient!)
    end
  end
  
  # Rotate the image 90 degrees clockwise
  #
  
  def rotate
    manipulate! do |image|
      img = image.rotate!(90)
      img
    end
  end

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  # Create different versions of your uploaded files:
  version :thumb do
    process :auto_orient
    process :resize_to_fit => [200, 200]
  end

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_white_list
    %w(jpg jpeg gif png bmp)
  end

  # Override the filename of the uploaded files:
  # Avoid using model.id or version_name here, see uploader/store.rb for details.
  #def filename
  #  "avatar.jpg" if original_filename
  #end
  
end
