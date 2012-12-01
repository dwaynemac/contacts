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
      :provider               => 'AWS',       # required
      :aws_access_key_id      => 'AKIAINBCXC7Y4PANEJOQ',       # required
      :aws_secret_access_key  => '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',       # required
      #:region                 => 'eu-west-1'  # optional, defaults to 'us-east-1'
    }
    if Rails.env.production?
      config.fog_directory = 'contacts-prod'
    else
      config.fog_directory  = 'contacts-dev'                     # required
    end
    config.fog_host       = "http://#{config.fog_directory}.s3.amazonaws.com"            # optional, defaults to nil
    #config.fog_public     = false                                   # optional, defaults to true
    #config.fog_attributes = {'Cache-Control'=>'max-age=315576000'}  # optional, defaults to {}
  end
end
