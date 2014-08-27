# See https://github.com/bigfive/capistrano-db-tasks-postgres
Capistrano::Configuration.instance.load do |instance|

  require File.expand_path("#{File.dirname(__FILE__)}/util")
  require File.expand_path("#{File.dirname(__FILE__)}/database")
  
  instance.set :stage, 'production' unless exists?(:stage)
  instance.set :db_local_clean, false unless exists?(:db_local_clean)

  namespace :db do
    namespace :remote do
      desc 'Synchronize the local database to the remote database'
      task :sync, :roles => :db do
        if Util.prompt 'Are you sure you want to REPLACE THE REMOTE DATABASE with local database'
          Database.local_to_remote(instance)
        end
      end
    end
    
    namespace :local do
      desc 'Synchronize your local database using remote database data'
      task :sync, :roles => :db do
        puts "Local database: #{Database::Local.new(instance).database}"
        if Util.prompt 'Are you sure you want to erase your local database with server database'
          Database.remote_to_local(instance)
        end
      end
      
      desc 'Dump local database'
      task :dump, :roles => :db do
        puts "Local database: #{Database::Local.new(instance).database}"
        Database::Local.new(instance).dump
      end
      
      desc 'Load local database from existing dump'
      task :load_dump, :roles => :db do
        if Util.prompt 'Are you sure you want to overwrite your local database with the contents of the local dump file'
          Database.load_local_dump(instance)
        end
      end
    end
    
    desc 'Synchronize your local database using remote database data'
    task :pull do 
      db.local.sync
    end
    
    desc 'Synchronize the local database to the remote database'
    task :push do 
      db.remote.sync
    end
  end
  
  # namespace :app do
  #   namespace :remote do
  #     desc 'Synchronize your remote assets AND database using local assets and database'
  #     task :sync do
  #       if Util.prompt "Are you sure you want to REPLACE THE REMOTE DATABASE AND your remote assets with local database and assets(#{assets_dir})"
  #         Database.local_to_remote(instance)
  #         Asset.local_to_remote(instance)
  #       end
  #     end
  #   end
  # 
  #   namespace :local do
  #     desc 'Synchronize your local assets AND database using remote assets and database'
  #     task :sync do
  #       puts "Local database     : #{Database::Local.new(instance).database}"
  #       puts "Assets directories : #{assets_dir}"
  #       if Util.prompt "Are you sure you want to erase your local database AND your local assets with server database and assets(#{assets_dir})"
  #         Database.remote_to_local(instance)
  #         Asset.remote_to_local(instance)
  #       end
  #     end
  #   end
  #   
  #   desc 'Synchronize your local assets AND database using remote assets and database'
  #   task :pull do 
  #     app.local.sync
  #   end
  # 
  #   desc 'Synchronize your remote assets AND database using local assets and database'
  #   task :push do 
  #     app.remote.sync
  #   end
  # end
end
