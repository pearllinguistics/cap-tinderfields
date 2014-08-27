require 'tinderfields/capistrano/symlinks'

Capistrano::Configuration.instance.load do |instance|
  # set(:additional_symlinks, fetch(:additional_symlinks, []) + 'solr/data')
  
  after 'deploy:setup', 'solr:setup_solr_data_dir'
  
  namespace :solr do
    desc "start solr"
    task :start, :roles => :app, :except => { :no_release => true } do 
      run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec sunspot-solr start --log-file=#{shared_path}/log/solr.log --data-directory=#{shared_path}/solr/data"
    end
    
    desc "stop solr"
    task :stop, :roles => :app, :except => { :no_release => true } do 
      run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec sunspot-solr stop"
    end

    desc "reindex the whole database"
    task :reindex, :roles => :app do
      # run "rm -rf #{shared_path}/solr/data"
      run "cd #{current_path} && RAILS_ENV=#{rails_env} bundle exec rake sunspot:reindex"
    end
    
    task :setup_solr_data_dir do
      run "mkdir -p #{shared_path}/solr/data"
    end
  end
end
