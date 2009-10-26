module ActiveRecord
  module ConnectionAdapters
    class MysqlAdapter
      # 使用InnoDB存储的MySql支持SAVEPOINT，但有些MySQL不支持（原因未知），故捕获SAVEPIONT相关异常
      alias :origin_create_savepoint :create_savepoint
      def create_savepoint
        #execute("SAVEPOINT #{current_savepoint_name}")
        origin_create_savepoint rescue nil
      end

      alias :origin_rollback_to_savepoint :rollback_to_savepoint
      def rollback_to_savepoint
        #execute("ROLLBACK TO SAVEPOINT #{current_savepoint_name}")
        origin_rollback_to_savepoint rescue nil
      end

      alias :origin_release_savepoint :release_savepoint
      def release_savepoint
        #execute("RELEASE SAVEPOINT #{current_savepoint_name}")
        origin_release_savepoint rescue nil
      end
    end
  end
end