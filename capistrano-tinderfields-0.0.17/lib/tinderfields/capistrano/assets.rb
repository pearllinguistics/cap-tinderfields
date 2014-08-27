Capistrano::Configuration.instance.load do |instance|
  # _cset :asset_folders, { 
  #   :attachments => 'htdocs/app/webroot/attachments', 
  #   :files => 'htdocs/app/webroot/files'
  # }
  # 
  # namespace :assets do
  #   task :pull do
  #   end
  #   
  #   task :push do
  #     transaction do
  #       asset_folders.each do |name, folder|
  #         filename = "#{name}.#{Time.now.strftime '%Y%m%d%H%M%S'}.tar.gz"
  #         
  #         on_rollback {
  #           run     "rm -f /tmp/#{filename}"
  #           system  "rm -f /var/tmp/#{filename}"
  #         }
  #         
  #         system  "tar cfz /var/tmp/#{filename} #{folder}"
  #         put     File.read("/var/tmp/#{filename}"), "/tmp/#{filename}"
  #         run     "gunzip -c /tmp/#{filename} | tar -xC #{shared_path}/#{folder}"
  #         run     "rm -f /tmp/#{filename}"
  #         system  "rm -f /var/tmp/#{filename}"
  #       end
  #     end
  #   end
  # end
  
  require File.expand_path("#{File.dirname(__FILE__)}/asset")
  
  _cset(:assets_dir, fetch(:no_rails, false) ? ['htdocs/app/webroot/attachments'] : ['public/system', 'system']) unless exists?(:assets_dir)
  
  namespace :assets do
    namespace :remote do
      desc 'Synchronize your remote assets using local assets'
      task :sync, :roles => :app do
        puts "Assets directories: #{assets_dir}"
        if Util.prompt "Are you sure you want to erase your server assets with local assets"
          Asset.local_to_remote(instance)
        end
      end
    end

    namespace :local do
      desc 'Synchronize your local assets using remote assets'
      task :sync, :roles => :app do
        puts "Assets directories: #{assets_dir}"
        if Util.prompt "Are you sure you want to erase your local assets with server assets"
          Asset.remote_to_local(instance)
        end
      end
    end
    
    desc 'Synchronize your local assets using remote assets'
    task :pull do 
      assets.local.sync
    end
    
    desc 'Synchronize the remote assets using local assets'
    task :push do 
      assets.remote.sync
    end
  end
end
