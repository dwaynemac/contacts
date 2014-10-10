# encoding: UTF-8
##
#
# based on https://gist.github.com/toobulkeh/8214198
#
namespace :rails do

  ##
  # Opens rails console.
  # You can put console options in first argument
  #
  # Usage
  # - cap production rails:console
  # - cap production rails:console[--sandbox]
  desc "Open the rails console on app host."
  task :console, [:console_options] do |t, args|
    on roles(:app), primary: true do |host|
      rails_env = fetch(:stage)
      execute_interactively "ruby #{current_path}/script/rails console #{rails_env} #{args[:console_options]}"  
    end
  end

  ##
  # Run a rake task.
  #
  # Usage
  # - cap production rails:rake[clear:cache]
  # - cap production rails:rake[check_account_for_errors,cervino]
  #
  desc "Runs rake task on app host."
  task :rake, [:task_name, :task_arguments, :rake_options] do |t, args|
    on roles(:app), primary: true do |host|
      rails_env = fetch(:stage)
      execute_interactively "RAILS_ENV=#{rails_env} bundle exec rake #{args[:task_name]}[#{args[:task_arguments]}] #{args[:rake_options]}"
    end
  end
 
  ##
  # Opens db console.
  # You can put console options in first argument
  #
  # Usage
  # - cap production rails:dbconsole
  desc "Open the rails dbconsole on db host."
  task :dbconsole, [:console_options] do |t, args|
    on roles(:db), primary: true do |host|
      rails_env = fetch(:stage)
      execute_interactively "ruby #{current_path}/script/rails dbconsole #{rails_env} #{args[:console_options]}"  
    end
  end
 
  def execute_interactively(command)
    exec "ssh #{fetch(:user)}@#{fetch(:domain)} -i #{fetch(:key_path)} -t 'cd #{current_path} && #{command}'"
  end
end
