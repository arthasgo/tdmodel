# To change this template, choose Tools | Templates
# and open the template in the editor.

module DBLayer
  # 获取数据中定义的表
  class << self
    def extract_db_tables (dbconfig_file="")
      unless @dbs
        if File.exist(dbconfig_file)
          load_dbconfig dbconfig_file
        else
          return
        end
      end

      @db_tbls = {:dbs=>{},:tables=>{}, :duplicated_tables=>[]}

      # 获取数据库中的表
      @dbs.each do |db,conn|
        begin
          ActiveRecord::Base.establish_connection conn
          case conn['adapter']
          when /^oracle$/i
            tbls = ActiveRecord::Base.connection.select_values("select table_name from user_tables")
            tbls.reject! {|t| t=~/^tmp/i}
          when /^mysql$/i
            tbls = ActiveRecord::Base.connection.select_values("show tables")
            tbls.reject! {|t| t=="schema_migrations"}
          else
            tbls = {}
          end

          # 把表名转换成小写
          @db_tbls[:dbs][db]=tbls.collect {|tbl| tbl.is_a?(String)? tbl.downcase : tbl}
        rescue =>err_info
          puts "db:#{db},#{err_info}"
          next
        end

        # 为数据表配置数据库
        @db_tbls[:dbs][db].each do |tbl|
          # 检查数据表是否存在
          if @db_tbls[:tables].has_key? tbl
            if @db_tbls[:duplicated_tables].select{|tbl_hash| tbl_hash.has_key? tbl}.empty?
              # 记录重复表
              @db_tbls[:duplicated_tables] << {tbl=>@db_tbls[:tables][tbl]}
            end
            @db_tbls[:duplicated_tables] << {tbl=>db}
          else
            @db_tbls[:tables][tbl] = db
          end
        end
      end

      # 释放数据库链接
      ActiveRecord::Base.establish_connection
      
      # 为数据表配置数据库
      @db_tbls
    end

    # 保存lint之后的数据库配置，请先调用load_dbconfig
    def save_db_tables()
      return unless @config_dir
      
      db_tbl_file = File.join(@config_dir,"dbtable.yml")
      File.open(db_tbl_file, 'wb') {|f| f.write(@db_tbls.to_yaml) }
    end
    
    private
    def load_dbtable_file()
      @dbtable_file = File.join(@config_dir,'dbtable.yml')
      @db_tbls ||= YAML::load_file @dbtable_file
    end
  end
end