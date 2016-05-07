ActionMailer::Base.add_delivery_method :ses, AWS::SES::Base,
  :access_key_id     => ENV['padma_aws_key_id'],
  :secret_access_key => ENV['padma_aws_secret_access_key']