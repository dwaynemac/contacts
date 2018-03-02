set :stage, :production

set :branch, 'aws-test'

set :ruby_version, '/usr/bin/ruby2.0'

set :default_env, -> {{ path: [fetch(:ruby_version), "#{release_path}/bin", "$PATH"].join(":") }}

set :rails_env, 'production'

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
