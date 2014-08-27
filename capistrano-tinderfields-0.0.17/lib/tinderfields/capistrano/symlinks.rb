Capistrano::Configuration.instance.load do |instance|
  before  'deploy:update_code', 'deploy:symlinks:setup'
  after   'deploy:create_symlink',     'deploy:symlinks:update'
  
  _cset :additional_symlinks, []
  
  namespace :deploy do
    namespace :symlinks do
    
      desc "Setup additional application symlinks"
      task :setup, :roles => [:web] do
        additional_symlinks.each do |link|
          link = link.first if link.is_a?(Array)
          run "mkdir -p #{shared_path}/#{link} && chmod g+w #{shared_path}/#{link}"
        end
      end
  
      desc "Symlink directories to shared location"
      task :update, :roles => [:web] do
        additional_symlinks.each do |link|
          link_a = link.is_a?(Array) ? link.first : link
          link_b = link.is_a?(Array) ? link.last : link
          run "ln -nfs #{shared_path}/#{link_a} #{release_path}/#{link_b}"
        end
      end
    
    end
  end
end
