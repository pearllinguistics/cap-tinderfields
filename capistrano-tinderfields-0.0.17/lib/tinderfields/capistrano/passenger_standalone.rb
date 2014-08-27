Capistrano::Configuration.instance.load do |instance|
  namespace :deploy do
    env_string = fetch(:env, {}).inject('') { |result, element| "#{result} #{element.first}=#{element.last}" }
    
  	task :start, :roles => :app do
  	  run "cd #{current_path} && #{env_string} bundle exec passenger start -a 127.0.0.1 -p #{passenger_port} -d -e #{rails_env}"
  	end

  	task :stop, :roles => :app do
  	  run "cd #{current_path} && bundle exec passenger stop -p #{passenger_port}"
  	end

  	desc "Restart Application"
  	task :restart, :roles => :app do
  	  run "cd #{current_path} && bundle exec passenger stop -p #{passenger_port}"
  	  run "cd #{current_path} && #{env_string} bundle exec passenger start -a 127.0.0.1 -p #{passenger_port} -d -e #{rails_env}"
  	end
  end
end
