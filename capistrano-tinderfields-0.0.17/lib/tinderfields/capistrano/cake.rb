Capistrano::Configuration.instance.load do |instance|
  after   'deploy:setup',             'cake:config'
  before  'deploy:update_code',       'cake:symlinks:setup'
  after   'deploy:create_symlink',    'cake:symlinks:update'
  after   'deploy:create_symlink',    'cake:add_htaccess'
  
  # #Need to add something to change permissions of initial files
  # #Need to do something to create various tmp subfolders and set their blasted permissions
  
  namespace :cake do
    set :cake_directories,              ['htdocs/app/tmp/cache', 'htdocs/app/tmp/cache/persistent', 'htdocs/app/tmp/cache/models']
    set :app_symlinks,                  ["htdocs/app/webroot/attachments", "htdocs/app/webroot/files", "htdocs/app/tmp"]
    set :cake_database_config_template, "database.php.erb"
    set :cake_database_config_location, "app/config/"
     
    namespace :config do
      desc "Configure new cake install"
      task :default, :roles => [:web] do
        cake.create_database_config_php
        cake.setup_directories
      end
    end
    
    task :create_database_config_php, :roles => [:web] do
      @config = YAML.load_file(File.join('config', 'database.yml'))[rails_env]
      file = File.join(File.dirname(__FILE__), "templates", cake_database_config_template)
      template = File.read(file)
      buffer = ERB.new(template).result(binding)
      put buffer, "#{shared_path}/#{cake_database_config_template.gsub('.erb', '')}"#, :mode => 0444
    end
    
    task :setup_directories, :roles => [:web] do
      fetch(:cake_directories, []).each do |link|
        run "mkdir -p #{shared_path}/#{link} && chmod g+w #{shared_path}/#{link}"
      end
    end
    
    namespace :symlinks do
      desc "Setup application symlinks in the public"
      task :setup, :roles => [:web] do    
        app_symlinks.each { |link| run "mkdir -p #{shared_path}/#{link}" } if app_symlinks
      end
      
      desc "Link public directories to shared location."
      task :update, :roles => [:web] do 
        if app_symlinks
          app_symlinks.each do |link| 
            run "rm -Rf #{current_path}/#{link}"
            run "ln -nfs #{shared_path}/#{link} #{current_path}/#{link}"
          end
        end
        
        file = "#{cake_database_config_location}#{cake_database_config_template.gsub('.erb', '')}" 
        send(run_method, "rm -f #{current_path}/htdocs/#{file}")
        send(run_method, "ln -nfs #{shared_path}/#{cake_database_config_template.gsub('.erb', '')} #{current_path}/htdocs/#{file}")
      end
    end
    
    namespace :upload do
      desc "upload and run latest db dump from local environment, touching up"
      task :db_dump, :roles => :db, :only => { :primary => true } do                    
        run "mkdir -p #{shared_path}/sql"
        full_filename = Dir.glob('./sql/*.sql').select {|f| File.file? f }.sort_by { |f| File.file?(f) ? File.mtime(f) : Time.mktime(0) }.last    
        filename = full_filename.gsub('./sql/', '')
        top.upload File.expand_path(full_filename), "#{shared_path}/sql/#{filename}"      
        
        run "mysql -u #{cake_db_user} --password=#{cake_db_password} #{cake_db_name} < \"#{shared_path}/sql/#{filename}\"" 
      end
      
      desc "upload files from local environment" #Not working
      task :files do
        app_symlinks.each { |dir| top.upload("#{local_app_dir}/#{dir}/*", File.join(current_path, dir)) }
      end
    end
    
    desc "add .htaccess"
    task :add_htaccess do
      run "cp #{shared_path}/cached-copy/htdocs/.htaccess #{current_path}/htdocs/.htaccess"
    end
  end
end
