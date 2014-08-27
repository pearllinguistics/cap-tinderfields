module Asset
  extend self

  def remote_to_local(cap)
    servers = cap.find_servers :roles => :app
    port = cap.port rescue 22
    [cap.assets_dir].each do |dir|
      dir_a, dir_b = dir.is_a?(Array) ? [dir.first, dir.last] : [dir, dir]
      system("rsync -a --del --progress --rsh='ssh -p #{port}' #{cap.user}@#{servers.first}:#{cap.shared_path}/#{dir_b}/ #{dir_a}/")
    end
  end
  
  def local_to_remote(cap)
    servers = cap.find_servers :roles => :app
    port = cap.port rescue 22
    [cap.assets_dir].each do |dir|
      dir_a, dir_b = dir.is_a?(Array) ? [dir.first, dir.last] : [dir, dir]
      system("rsync -a --del --progress --rsh='ssh -p #{port}' #{dir_a}/ #{cap.user}@#{servers.first}:#{cap.shared_path}/#{dir_b}/")
    end
  end

end
