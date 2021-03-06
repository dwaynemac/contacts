namespace :delayed_job do

  def args
    fetch(:delayed_job_args, "")
  end

  def delayed_job_roles
    fetch(:delayed_job_server_role, :app)
  end

  desc 'Stop the delayed_job process'
  task :stop do
    on roles(delayed_job_roles) do
      within release_path do    
        with rails_env: fetch(:rails_env), rbenv_ruby: fetch(:rbenv_ruby) do
          execute :bundle, :exec, :'script/delayed_job', :stop
        end
      end
    end
  end

  desc 'Start the delayed_job process'
  task :start do
    on roles(delayed_job_roles) do
      within release_path do
        with rails_env: fetch(:rails_env), rbenv_ruby: fetch(:rbenv_ruby) do
          # eexecute "rm tmp/pids/delayed_job.pid" # to FORCE process starting
          execute :bundle, :exec, :'script/delayed_job', args, :start
        end
      end
    end
  end
  
  desc 'Start the delayed_job process, removes pid file first'
  task :force_start do
    on roles(delayed_job_roles) do
      within release_path do
        with rails_env: fetch(:rails_env), rbenv_ruby: fetch(:rbenv_ruby) do
          execute "rm tmp/pids/delayed_job.pid" # to FORCE process starting
          execute :bundle, :exec, :'script/delayed_job', args, :start
        end
      end
    end
  end

  desc 'Restart the delayed_job process'
  task :restart do
    on roles(delayed_job_roles) do
      within release_path do
        with rails_env: fetch(:rails_env), rbenv_ruby: fetch(:rbenv_ruby) do
          execute :bundle, :exec, :'script/delayed_job', args, :restart
        end
      end
    end
  end

end
