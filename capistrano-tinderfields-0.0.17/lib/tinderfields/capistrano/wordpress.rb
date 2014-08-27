Capistrano::Configuration.instance.load do |instance|
  after   'deploy:setup',       'wordpress:config'
  before  'deploy:update_code', 'wordpress:symlinks:setup'
  after   'deploy:symlink',     'wordpress:symlinks:update'
  # after   'deploy:symlink',     'wordpress:htaccess:add'
  
  namespace :wordpress do
    set :app_symlinks,        ["wp-content/uploads", "wp-content/cache", "wp-content/authors", "wp-content/avatar", "wp-content/plugins/post-notification/_temp"]
    set :wp_config_template,  "wp-config.php.erb"
    set :local_app_dir,       "htdocs"
    set :local_app,           "blog.hindecapital.com"
   
    task :wp_config_php, :roles => [:web] do
      file = File.join(File.dirname(__FILE__), "templates", wp_config_template)
      template = File.read(file)
      buffer = ERB.new(template).result(binding)
      put buffer, "#{shared_path}/wp-config.php", :mode => 0664
    end
  
    desc "Save a db dump locally"
    task :create_db_dump do
    end
  
    namespace :symlinks do
      desc "Setup application symlinks in the public"
      task :setup, :roles => [:web] do    
        if app_symlinks
          app_symlinks.each do |link| 
            run "mkdir -p #{shared_path}/#{link} && chmod g+w #{shared_path}/#{link}"
          end
        end
      end
    
      desc "Link public directories to shared location."
      task :update, :roles => [:web] do
        from_path = wp_blog_path ? "#{release_path}/#{wp_blog_path}" : release_path
      
        if app_symlinks
          app_symlinks.each { |link| run "ln -nfs #{shared_path}/#{link} #{from_path}/#{link}" }
        end
      
        send(run_method, "rm -f #{from_path}/wp-config.php")
        send(run_method, "ln -nfs #{shared_path}/wp-config.php #{from_path}/wp-config.php")
      end
    end
  
    namespace :config do
      desc "Configure new wordpress install"
      task :default, :roles => [:web] do
        wordpress.wp_config_php
        #apache.vhost
      end
    end
  
    namespace :htaccess do
      desc "add .htaccess"
      task :add do
        #run "rm #{path}/.htaccess"
        run "cp #{shared_path}/cached-copy/.htaccess #{current_path}/.htaccess"
      end
    end

    namespace :upload do
      desc "upload and run latest db dump from local environment, touching up"
      task :db_dump, :roles => :db, :only => { :primary => true } do
        run "mkdir -p #{shared_path}/sql"
        full_filename = Dir.glob('./tmp/sql/*.sql').select { |f| File.file? f }.sort_by { |f| File.file?(f) ? File.mtime(f) : Time.mktime(0) }.last
        filename = full_filename.gsub('./tmp/sql/', '')
        top.upload File.expand_path(full_filename), "#{shared_path}/sql/#{filename}"
      
        local_url = "http://#{local_app}"
        remote_url = "http://#{domain}#{wp_blog_url}"
      
        password = Capistrano::CLI.ui.ask("Enter Wordpress #{stage} database password: ")
      
        run "mysql -u #{wp_db_user} --password=#{password} #{wp_db_name} < #{shared_path}/sql/#{filename}" 
        [
          "UPDATE wp_options SET option_value = replace(option_value, '#{local_url}', '#{remote_url}') WHERE option_name = 'home' OR option_name = 'siteurl'",
          "UPDATE wp_posts SET guid = replace(guid, '#{local_url}','#{remote_url}')",
          "UPDATE wp_posts SET post_content = replace(post_content, '#{local_url}', '#{remote_url}')"
        ].each { |c| run "mysql -u #{wp_db_user} --password=#{password} #{wp_db_name} -e \"#{c}\"" }
      end
    
      #Not working
      desc "upload files from local environment" 
      task :files do
        app_symlinks.each { |dir| top.upload("#{local_app_dir}/#{dir}/*", File.join(current_path, dir)) }
      end
    end
  end
end
