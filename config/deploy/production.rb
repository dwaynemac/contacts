set :stage, :production

set :branch, 'production'

set :rails_env, 'production'

set :bundle_without, 'development:test:heroku:deploying'

set :domain, 'pending'
set :worker_host, '54.211.11.34'
set :user, 'ec2-user'
set :key_path, "#{File.dirname(File.realpath(__FILE__))}/production.pem"

server fetch(:domain),
       name: 'contacts-app-capified',
       user: fetch(:user),
       roles: %w(web app),
       ssh_options: {
         keys: [fetch(:key_path)],
         auth_methods: %w(publickey)
       }

server fetch(:worker_host),
       name: 'contacts-worker',
       user: fetch(:user),
       roles: %w(app worker),
       ssh_options: {
         keys: [fetch(:key_path)],
         auth_methods: %w(publickey)
       }
