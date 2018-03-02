set :stage, :production

set :branch, 'aws-test'

set :rails_env, 'production'

set :rbenv_type, :user 
set :rbenv_ruby, File.read('.ruby-version').strip
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby rails}
set :rbenv_roles, :all # default value

set :bundle_without, 'development:test:heroku:deploying'

set :web_host, '54.167.128.20'
# set :worker_host, '54.211.11.34'

set :user, 'ec2-user'
set :key_path, "#{File.dirname(File.realpath(__FILE__))}/production.pem"

role :web, fetch(:web_host)
role :worker, fetch(:web_host)

server fetch(:web_host),
       name: 'contacts-app-capified',
       user: fetch(:user),
       roles: %w(web app worker),
       ssh_options: {
         keys: [fetch(:key_path)],
         auth_methods: %w(publickey)
       }

=begin
server fetch(:worker_host),
       name: 'contacts-worker',
       user: fetch(:user),
       roles: %w(app worker),
       ssh_options: {
         keys: [fetch(:key_path)],
         auth_methods: %w(publickey)
       }
=end
