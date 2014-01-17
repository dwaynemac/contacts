if Rails.env.test? or Rails.env.cucumber?
  CarrierWave.configure do |config|
    config.storage = :file
    config.enable_processing = true
  end
else
  CarrierWave.configure do |config|
    config.cache_dir = "#{Rails.root}/tmp/uploads"
    config.storage = :fog
    config.fog_credentials = {
        :provider               => 'AWS',
        :aws_access_key_id      => ENV['aws_access_key_id'],
        :aws_secret_access_key  => ENV['aws_secret_access_key'],
    }
    config.fog_directory  =        ENV['aws_bucket']
    config.fog_host       =        ENV['aws_host']

    #config.fog_public     = false                                   # optional, defaults to true
    #config.fog_attributes = {'Cache-Control'=>'max-age=315576000'}  # optional, defaults to {}
  end
end