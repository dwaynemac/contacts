set :stage, :production

set :branch, 'capistrano'

set :rails_env, 'production'

set :bundle_without, 'development:test:heroku:deploying'

set :domain, 'pending'
set :user, 'ec2-user'
set :key_path, "#{File.dirname(File.realpath(__FILE__))}/production.pem"

server fetch(:domain),
       name: 'capistrano-test',
       user: fetch(:user),
       roles: %w(web app),
       ssh_options: {
         keys: [fetch(:key_path)],
         auth_methods: %w(publickey)
       }
