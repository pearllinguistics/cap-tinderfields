Capistrano::Configuration.instance.load do |instance|
  after "deploy:symlink", "delayed_job:restart"
  
  _cset(:worker_count, 1) unless exists?(:worker_count)
  _cset(:use_monit_for_delayed_job, true) unless exists?(:use_monit_for_delayed_job)

  namespace :delayed_job do
    env_string = fetch(:env, {}).inject('') { |result, element| "#{result} #{element.first}=#{element.last}" }
    
    desc "Start delayed job workers"
    task :start, :roles => :worker do
      if use_monit_for_delayed_job
        run "sudo monit -g #{application} start"
      else
        run "cd #{current_path} && RAILS_ENV=#{rails_env} #{env_string} script/delayed_job start -n #{worker_count} --prefix #{application}"
      end
    end

    desc "Stop delayed job workers"
    task :stop, :roles => :worker do
      if use_monit_for_delayed_job
        run "sudo monit -g #{application} stop"
      else  
        run "cd #{current_path} && RAILS_ENV=#{rails_env} #{env_string} script/delayed_job stop"
      end
    end

    desc "Restart delayed jobs (in the background)"
    task :restart, :roles => :worker do
      if use_monit_for_delayed_job
        run "sudo monit -g #{application} restart"
      else  
        delayed_job::stop
        delayed_job::start
      end
    end
  end
end
