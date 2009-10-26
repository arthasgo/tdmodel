# To change this template, choose Tools | Templates
# and open the template in the editor.

module DBLayer
  class << self
    # 使用magic_multi_connections插件，为每个数据库创建一个模块，实现多数据库并发访问
    def concurrent_multi_dbs()
      @dbs.each do |db_name,db_config|
        db_module = get_db_module_name db_name

        Object.class_eval <<-EOS
        module #{db_module}
          db_config = #{db_config.inspect}
          establish_connection db_config
        end
        EOS
        
        db_module.constantize
      end
    end

    # 检查数据配置
    def load_dbconfig(dbconfig_file)
      @dbconfig_file = dbconfig_file
      @config_dir = File.dirname dbconfig_file
      
      @dbs = YAML::load_file dbconfig_file
      @linted_dbs = {}

      # 为了支持多数据库链接，数据库名称转换成模块名称后要唯一
      dbname_to_module = {}
      @dbs.each do |db_name,config|
        db_module_name = get_db_module_name db_name
        if db_module_name.strip.empty?
          puts "warning: database '#{db_name}' is invalid, should be in underscore format"
          next
        end

        if dbname_to_module.has_key? db_module_name
          puts "warning: databases '#{dbname_to_module[db_module_name]}' and '#{db_name}' are conflicted with the same classify name '#{db_module_name}', please change database name"
        end

        dbname_to_module[db_module_name]=db_name

        @linted_dbs[db_module_name] = config
      end

      @dbs
    end

    def get_dbconfig(db)
      dbconfig = @dbs[db]||{}
      puts("warning: can't find #{db} config in #{@dbconfig_file}") if dbconfig.empty?
      dbconfig
    end
    
    # 保存lint之后的数据库配置，请先调用load_dbconfig
    def save_linted_dbconfig(dbconfig_file="")
      unless @linted_dbs
        if File.exist(dbconfig_file)
          load_dbconfig dbconfig_file
        else
          return
        end
      end

      linted_file = File.join @config_dir,'dbconfig_linted.yml'
      File.open(linted_file, 'wb') {|f| f.write(@linted_dbs.to_yaml) }
    end

    def next_sequence_value(db,sequence_name)
      spec = ActiveRecord::Base.connection_pool.spec
      
      ActiveRecord::Base.establish_connection DBLayer.get_dbconfig(db)
      conn = ActiveRecord::Base.connection
      value = conn.next_sequence_value sequence_name

      ActiveRecord::Base.establish_connection spec
      
      value
    end

    private
    def get_db_module_name(db_name)
      db_name.gsub(/[^0-9a-z]+/i,'_').upcase
    end
  end
end
