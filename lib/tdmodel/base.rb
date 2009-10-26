# To change this template, choose Tools | Templates
# and open the template in the editor.

module Tdmodel
  class Base
    class << self
      # 保存
      def set_db_conn(db,table,tdmodel=self::MasterModel)
        db_conn = DbConn.new(db,table,tdmodel)
        db_conn.establish_connection

        db_conn
      end
    end
  end

  class DbConn
    attr_accessor :original_conn_spec,:conn_spec,:original_table
    
    def initialize(db,table,tdmodel)
      @db,@table,@tdmodel=db,table,tdmodel
    end

    def establish_connection
      @ar_tdmodel = @tdmodel.constantize rescue nil
      unless @ar_tdmodel && @ar_tdmodel.ancestors.include?(ActiveRecord::Base)
        puts "can't find orm class #{@td_model} which is the descendant fo ActiveRecord::Base"
        return nil
      end

      self.original_conn_spec = @ar_tdmodel.connection_pool.spec
      self.original_table = @ar_tdmodel.table_name
      
      db_config = DBLayer.get_dbconfig @db
      @ar_tdmodel.establish_connection db_config
      @ar_tdmodel.set_table_name @table

      self.conn_spec = @ar_tdmodel.connection_pool.spec
    end

    def restore_connection
      if @ar_tdmodel
        @ar_tdmodel.establish_connection original_conn_spec
        @ar_tdmodel.set_table_name original_table
      end
    end

    def to_yaml_properties
      %w{@db @table @tdmodel}
    end
  end
end