require 'tinderfields/capistrano/database_tasks'

Capistrano::Configuration.instance.load do |instance|
  after   'deploy:setup',             'php:config'
  after   'deploy:create_symlink',    'php:link_database_config_php'  

  namespace :php do
    _cset :database_config_location, ""
     
    namespace :config do
      desc "Configure new php install"
      task :default, :roles => [:web] do
        php.create_database_config_php
      end
    end
    
    task :create_database_config_php, :roles => [:web] do
      @config = YAML.load_file(File.join('config', 'database.yml'))[rails_env]      
      filename = fetch(:php_database_config_template, 'database_details.php.erb')
      template = File.file?("config/#{filename}") ? File.read("config/#{filename}") : File.read("#{File.dirname(__FILE__)}/templates/#{filename}")
      buffer = ERB.new(template).result(binding)
      put buffer, "#{shared_path}/#{filename.gsub('.erb', '')}"#, :mode => 0444
    end
    
    task :link_database_config_php, :roles => [:web] do
      filename = fetch(:php_database_config_template, 'database_details.php.erb')
      send(run_method, "rm -f #{current_path}/htdocs/#{database_config_location}#{filename.gsub('.erb', '')}")
      send(run_method, "ln -nfs #{shared_path}/#{filename.gsub('.erb', '')} #{current_path}/htdocs/#{database_config_location}#{filename.gsub('.erb', '')}")
    end
  end
end
