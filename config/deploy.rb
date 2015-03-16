## 
# TODO : get ideas from https://github.com/TalkingQuickly/capistrano-3-rails-template

# config valid only for Capistrano 3.2.1
lock '3.2.1'

set :application, 'contacts'
set :repo_url, 'git@github.com:dwaynemac/contacts.git'

# TODO generate lib/unicorn/{stage}.rb dinamycally using this var
set :deploy_to, '/home/ec2-user/contacts'

# Default value for :log_level is :debug
# set :log_level, :debug

set :assets_roles, []

# Default value for :pty is false
set :pty, true

# Default value for :linked_files is []
set :linked_files, %w{config/mongoid.yml config/application.yml}

set :config_files, %w{mongoid.yml application.yml}
set :executable_config_files, []

# Default value for linked_dirs is []
set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system}

set :bundle_bins, %w(rails rake appsignal gem)

set :unicorn_roles, %w(web)
set :unicorn_options, "-p 5000"
set :unicorn_rack_env, 'production'

set :delayed_job_server_role, %w(worker)

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do

  after :publishing, :restart

  desc 'Restart application'
  task :restart do
    invoke 'unicorn:restart'
    invoke 'delayed_job:restart'
  end

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
end

desc 'show ssh command'
task :ssh_line do
  puts "web"
  puts "ssh #{fetch(:user)}@#{fetch(:web_host)} -i #{fetch(:key_path)}"
  puts "worker"
  puts "ssh #{fetch(:user)}@#{fetch(:worker_host)} -i #{fetch(:key_path)}"
end

task :open_ssh, [:role] do |t, args|
  args[:role] = :worker if args[:role].nil?
  on roles(args[:role]) do |host|
    exec "ssh #{fetch(:user)}@#{host} -i #{fetch(:key_path)}"
  end
end
