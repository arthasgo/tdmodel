module ActiveRecord
  module ConnectionAdapters #:nodoc:
    class Column
      alias :original_type_cast_code :type_cast_code

      # 自动转换数据库编码
      def type_cast_code(var_name)
        case type
        when :string    then "self.class.to_rails_encoding(#{var_name})"
        when :text      then "self.class.to_rails_encoding(#{var_name})"
        else original_type_cast_code(var_name)
        end
      end
    end
  end
end