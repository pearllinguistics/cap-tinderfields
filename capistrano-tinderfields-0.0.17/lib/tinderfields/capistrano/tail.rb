Capistrano::Configuration.instance.load do |instance|
  # Pay attention to various logfiles on all the remote servers
  namespace :tail do
    desc "tail rails application logs"
    task :app, :roles => :app do
      tail_logs("#{shared_path}/log/#{rails_env}.log")
    end

    desc "tail delayed_job worker logs"
    task :jobs, :roles => :worker do
      tail_logs("#{shared_path}/log/delayed_job.log")
    end
  end

  def tail_logs(files)
    run("tail -n0 -f #{files}") do |channel, stream, data|
      puts  # for an extra line break before the host name
      print "#{channel[:host]}: #{data}"
    end
  end
end
