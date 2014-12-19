namespace :deploy do
  
  desc "setup server for app's first deployment"
  task :setup => [:setup_system, :setup_config]

  desc 'install needed libraries on amazon ec2 amazon AMI'
  task :setup_system do
    on roles(:app) do
      # setup for AWS EC2 m1.small with amazon AMI
      execute :sudo, 'yum install gcc git ruby19 ruby19-devel rubygems19 libffi-devel ImageMagick-devel libstdc++-devel gcc-c++'
      execute :sudo, 'alternatives --set ruby /usr/bin/ruby1.9'
      execute :sudo, 'gem install bundler'
    end
  end

  task :setup_config do
    on roles(:app) do
      # make the config dir
      execute :mkdir, "-p #{shared_path}/config"

      fetch(:config_files).each do |file|
        execute :touch, "#{shared_path}/config/#{file}"
        # smart_template file
      end

      # which of the above files should be marked as executable
      fetch(:executable_config_files).each do |file|
        execute :chmod, "+x #{shared_path}/config/#{file}"
      end
    end
  end
end
