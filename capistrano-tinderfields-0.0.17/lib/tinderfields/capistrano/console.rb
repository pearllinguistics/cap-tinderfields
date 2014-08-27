Capistrano::Configuration.instance(:must_exist).load do
  namespace :rails do
    desc "Remote console"
    task :console, :roles => :app do
      run_interactively "bundle exec rails console #{rails_env}"
    end

    desc "Remote dbconsole"
    task :dbconsole, :roles => :app do
      run_interactively "bundle exec rails dbconsole #{rails_env}"
    end

    def run_interactively(command, server=nil)
      env_string = fetch(:env, {}).inject('') { |result, element| "#{result} #{element.first}=#{element.last}" }
      server ||= find_servers_for_task(current_task).first
      command = %Q(ssh -l #{user} #{server.host} -t 'source ~/.profile && cd #{current_path} && #{env_string} && #{command}')
      puts command
      exec command
    end
  end
end
