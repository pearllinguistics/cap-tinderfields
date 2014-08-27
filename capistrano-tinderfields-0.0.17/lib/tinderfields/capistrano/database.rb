module Database
  class Base 
    attr_accessor :config, :output_file
    
    def initialize(cap_instance)
      @cap = cap_instance
    end
    
    def postgresql?
      @config['adapter'] == 'postgresql'
    end
    
    def mysql?
      @config['adapter'] == 'mysql' || @config['adapter'] == 'mysql2'
    end
    
    def adapter
      return 'mysql' if mysql?
      return 'postgresql' if postgresql?
    end
    
    def credentials
      send "#{adapter}_credentials"
    end
    
    def mysql_credentials
      " -u #{@config['username']} " + (@config['password'] ? " -p\"#{@config['password']}\" " : '') + (@config['host'] ? " -h #{@config['host']}" : '')
    end
    
    def postgresql_credentials
      "-U #{@config['username']} " + (@config['host'] ? " -h #{@config['host']}" : '')
    end
    
    
    def postgres_password
      "PGPASSWORD=#{@config['password']}" if postgresql?
    end
    
    def database
      @config['database']
    end
    
    def output_file
      @output_file ||= "db/dump_#{database}.sql.bz2"
    end
    
  private
  
    def dump_cmd
      send "#{adapter}_dump_cmd"
    end
    
    def import_cmd(file)
      send "#{adapter}_import_cmd", file
    end
  
    def mysql_dump_cmd
      "mysqldump #{credentials} #{database}"
    end

    def mysql_import_cmd(file)
      "mysql #{credentials} -D #{database} < #{file}"
    end

    def postgresql_dump_cmd
      "pg_dump #{credentials} -xcO #{database}"
    end

    def postgresql_import_cmd(file)
      "#{postgres_password} psql #{credentials} #{database} < #{file}"
    end
    
    def postgresql_drop_table_cmd
      "select 'drop table \\\"' || tablename || '\\\" cascade;' from pg_tables where schemaname = 'public';\n"
    end
    
    def mysql_drop_table_cmd
      "select concat('DROP TABLE #{database}.', table_name,';') from information_schema.TABLES where table_schema='#{database}';"
    end
    
    def drop_sequence_cmd
<<-END
SELECT string_agg('DROP SEQUENCE ' || quote_ident(c.relname) || ';', '\n') FROM   pg_class c LEFT   JOIN pg_depend d ON d.refobjid = c.oid AND d.deptype <> 'i' WHERE  c.relkind = 'S' AND    d.refobjid IS NULL;
END
    end
    
    def empty_cmd
      send "#{adapter}_empty_cmd"
    end
    
    def postgresql_empty_cmd
      %Q{#{postgres_password} psql #{credentials} #{database} -t -c "#{postgresql_drop_table_cmd}" | #{postgres_password} psql #{credentials} #{database} && #{postgres_password} psql #{credentials} #{database} -t -c "#{drop_sequence_cmd}" | #{postgres_password} psql #{credentials} #{database}}
    end
    
    def mysql_empty_cmd
      %Q{mysql #{credentials} -D #{database} -e "#{mysql_drop_table_cmd}" --batch --skip-column-names | mysql #{credentials} -D #{database}}
    end
  end

  class Remote < Base
    def initialize(cap_instance)
      super(cap_instance)
      yaml_string = ""
      @cap.run("cat #{@cap.current_path}/config/database.yml") { |c,s,d| yaml_string += d }
      @config = YAML.load(yaml_string)[(@cap.rails_env || 'production').to_s]
    end
          
    def dump
      @cap.run "cd #{@cap.current_path}; #{postgres_password} #{dump_cmd} | bzip2 - - > #{output_file}"
      self
    end
    
    def download(local_file = "#{output_file}")
      remote_file = "#{@cap.current_path}/#{output_file}"
      @cap.get remote_file, local_file
    end
    
    # cleanup = true removes the mysqldump file after loading, false leaves it in db/
    def load(file, cleanup)
      unzip_file = File.join(File.dirname(file), File.basename(file, '.bz2'))
      @cap.run "cd #{@cap.current_path}; bunzip2 -f #{file} && #{empty_cmd} && RAILS_ENV=#{@cap.rails_env} && #{import_cmd(unzip_file)}"
      File.unlink(unzip_file) if cleanup
    end
  end

  class Local < Base
    def initialize(cap_instance)
      super(cap_instance)
      @config = YAML.load_file(File.join('config', 'database.yml'))[@cap.local_rails_env]
    end
    
    # cleanup = true removes the mysqldump file after loading, false leaves it in db/
    def load(file, cleanup)
      unzip_file = File.join(File.dirname(file), File.basename(file, '.bz2'))
      system("bunzip2 -f #{file}")
      import(unzip_file)
      File.unlink(unzip_file) if cleanup
    end

    def import(unzip_file)
      system("bundle exec rake db:drop db:create && #{import_cmd(unzip_file)}") 
    end
    
    def dump
      system "#{dump_cmd} | bzip2 - - > #{output_file}"
      self
    end
    
    def upload
      remote_file = "#{@cap.current_path}/#{output_file}"
      @cap.upload output_file, remote_file
    end
  end
  
  class << self
    def check(local_db, remote_db)
      if local_db.adapter != remote_db.adapter
        raise 'Remote and local servers must use the same adapter'
      end
    end

    def remote_to_local(instance) 
      local_db  = Database::Local.new(instance)
      remote_db = Database::Remote.new(instance)

      check(local_db, remote_db)
    
      remote_db.dump.download
      local_db.load(remote_db.output_file, instance.fetch(:db_local_clean))
    end
    
    def local_to_remote(instance)
      local_db  = Database::Local.new(instance)
      remote_db = Database::Remote.new(instance)

      check(local_db, remote_db)
      
      local_db.dump.upload
      remote_db.load(local_db.output_file, instance.fetch(:db_local_clean))
    end

    def load_local_dump(instance)
      local_db  = Database::Local.new(instance)
      remote_db = Database::Remote.new(instance)

      local_db.import(remote_db.output_file.gsub(/\.bz2$/, ''))
    end
  end
end