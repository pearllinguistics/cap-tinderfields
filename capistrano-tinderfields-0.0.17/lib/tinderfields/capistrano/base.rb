require 'tinderfields/capistrano/symlinks'
require 'tinderfields/capistrano/database_tasks'
require 'tinderfields/capistrano/tail'
require 'tinderfields/capistrano/maintenance'
require 'tinderfields/capistrano/assets'
require 'tinderfields/capistrano/console'

Capistrano::Configuration.instance.load do |instance|
  
  #
  # Configuration
  #

  # Multistage
  _cset :multistage, false
  
  if multistage
    require 'capistrano/ext/multistage'
    _cset :stages, %w(production staging)
  end

  # User details
  _cset :user,          'deployer'
  # _cset(:group)         { user }

  # Application details
  _cset(:application)      { abort "Please specify the short name of your application, set :application, 'foo'" }
  _cset(:domain)        { abort "Please specify the primary domain of your application, set :domain, 'foo.com'" }
  #_cset(:runner)        { user }
  _cset :use_sudo,      false
  _cset :keep_releases, 5

  # SCM settings
  _cset(:appdir)        { "/var/www/sites/#{application}" }
  _cset :scm,           'git'
  _cset :git_enable_submodules, 1

  _cset :branch,        'master'
  set :deploy_via,    :remote_cache
  set(:deploy_to)       { appdir }
  #set :copy_exclude, [".git/*", ".svn/*", ".DS_Store"]

  # Git settings for capistrano
  default_run_options[:pty]     = true # needed for git password prompts
  ssh_options[:forward_agent]   = true # use the keys for the person running the cap command to check out the app

  # RVM Settings
  _cset :rvm_ruby_string, ENV['GEM_HOME'].gsub(/.*\//,"")
  _cset :rvm_type, :system
  
  _cset :local_rails_env, ENV['RAILS_ENV'] || 'development' unless exists?(:local_rails_env)
  _cset :rails_env, 'production' unless exists?(:rails_env)
  _cset :rails_ver, 3 unless exists?(:rails_env)
  
  #
  # Dependencies
  #
  require 'tinderfields/capistrano/database_yaml' unless fetch(:no_rails, false)
  require "bundler/capistrano" unless fetch(:no_rails, false) # Have Capistrano automatically install your app’s gems for you
  require "rvm/capistrano"
  
  depend :remote, :directory, :writeable, "/var/www/sites"

  #
  # Runtime Configuration, Recipes & Callbacks
  #

  namespace :tinderfields do
    task :ensure do
      # This is to determine whether the app is behind a load balancer on another host.
      # Default to false, which means that we do expect the :internal_balancer and :external_balancer
      # roles to exist.
      _cset(:standalone) { false }
      _cset(:no_rails) { false }
        
      self.load do
        namespace :deploy do
          namespace :web do
            if standalone
              # These tasks will run on each app server
              desc "Disable requests to the app, show maintenance page"
              task :disable, :roles => :web do
                run "ln -nfs #{current_path}/public/maintenance.html #{current_path}/public/maintenance-mode.html"
              end
  
              desc "Re-enable the web server by deleting any maintenance file"
              task :enable, :roles => :web do
                run "rm -f #{current_path}/public/maintenance-mode.html"
              end
            else
              # These tasks will run on the load balancers
              desc "Disable requests to the app, show maintenance page"
              task :disable, :roles => :load_balancer do
                run "touch /etc/webdisable/#{app_name}"
              end
  
              desc "Re-enable the web server by deleting any maintenance file"
              task :enable, :roles => :load_balancer do
                run "rm -f /etc/webdisable/#{app_name}"
              end
            end
          end
        end
      end
    end
  end
  
  if fetch(:no_rails, false)
    # Remove Railsisms
    namespace :deploy do
      [:finalize_update, :restart].each do |default_task|
        task default_task do 
          # ... ahh, silence!
        end
      end
    end
  else
    namespace :deploy do
      task :start do ; end
      task :stop do ; end
      task :restart, :roles => :app, :except => { :no_release => true } do
        run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
      end
    end
  end
  
  # Make mycorp:ensure run immediately after the stage-specific config is loaded
  # This means it can make use of variables specified in _either_ the main deploy.rb
  # or any of the stage files.
  on :after, "tinderfields:ensure"#, :only => stages
  
  before 'deploy:setup', 'rvm:install_ruby'
  
  after "deploy:update", "deploy:cleanup"
      
  #
  # Recipes
  #

  # Deploy tasks for Passenger
  # namespace :deploy do
  #   desc "Restarting mod_rails with restart.txt"
  #   task :restart, :roles => :app, :except => { :no_release => true } do
  #     run "touch #{current_path}/tmp/restart.txt"
  #   end
  # 
  #   [:start, :stop].each do |t|
  #     desc "#{t} task is a no-op with mod_rails"
  #     task t, :roles => :app do ; end
  #   end
  # end
end
