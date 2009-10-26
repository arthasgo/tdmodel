# 实现从Rails UTF8编码到数据库本地编码的转换
module ActiveRecord
  class Base
    alias :original_write_attribute :write_attribute
    def write_attribute(attr_name, value)
      value = self.class.to_db_encoding(value) if transform_encoding_column?(attr_name)
      original_write_attribute(attr_name, value)
    end

    alias :original_read_attribute :read_attribute
    def read_attribute(attr_name)
      value = original_read_attribute attr_name
      value = self.class.to_rails_encoding(value) if transform_encoding_column?(attr_name)

      value
    end

    def new_record!
      @new_record = true
    end

    alias :original_attributes_with_quotes :attributes_with_quotes
    def attributes_with_quotes(*args)
      quoted = original_attributes_with_quotes *args
      quoted.each do |k,v|
        quoted[k] = self.class.to_db_encoding(v) if v.is_a? String
      end

      quoted
    end

    # 修改ActiveRecord的BUG，以支持多个save/save!/delete可以放在一个transaction中
    alias :origin_with_transaction_returning_status :with_transaction_returning_status
    def with_transaction_returning_status(method, *args)
#      self.class.connection.increment_open_transactions
      ret = origin_with_transaction_returning_status method,*args
#      self.class.connection.decrement_open_transactions
      
      ret
    end

    protected
    def transform_encoding_column?(attr_name)
      col = column_for_attribute(attr_name)

      (!col.nil? && (col.type==:string || col.type==:text)) ? true : false
    end

    class << self
      # 设置数据表编码，并开启编码自动转换
      def set_table_charset(value = nil, &block)
        define_class_variable_accessor :table_charset, value, &block
        set_auto_transform_encoding true
      end
      alias :table_charset= set_table_charset

      # 设置是否开启编码自动转换
      def set_auto_transform_encoding(value = true, &block)
        #logger.info "auto transform encoding for #{self.class} is enabled, to disable it by calling #{self.class}.set_auto_transform_encoding false" if value
        define_class_variable_accessor :auto_transform_encoding, value, &block
      end
      alias :auto_transform_encoding= set_auto_transform_encoding

      # 查询条件编码转换
      alias :original_merge_conditions :merge_conditions
      def merge_conditions(*conditions)
        sql = original_merge_conditions *conditions
        sql = to_db_encoding(sql)
        sql
      end

      def connection_spec
        connection_pool.spec
      end

      # 转换成gbk编码
      def to_db_encoding(str)
        return str unless transform_encoding?
        return str if str.blank?

        case self.table_charset
        when /^gbk|gb2312|gb18030$/i
          #puts "#{str} to to_db_encoding"
          Kconv.isutf8(str)? Iconv.conv('gb2312//IGNORE','utf-8//IGNORE',str): str
        when /^utf|utf-8$/
          str
        else
          puts "warning: not supported encoding #{self.class.table_charset}"
          str
        end
      end

      # 将 GB2312 编码的字符串转换为 UTF-8 编码的字符串
      def to_rails_encoding(str)
        return str unless transform_encoding?
        return str if str.blank?

        case self.table_charset
        when /^gbk|gb2312|gb18030$/i
          # Kconv.isutf8并不能很好来判定编码。比如“状态”这个词就会被误认为utf8
          #puts "#{str} to to_rails_encoding"
          Iconv.conv('utf-8//IGNORE','gb2312//IGNORE',str)
        when /^utf8|utf-8$/
          str
        else
          puts "warning: not supported encoding #{self.class.table_charset}"
          str
        end
      end

      protected
      def define_class_variable_accessor(name, value=nil, &block)
        sing = class << self; self; end
        sing.send :alias_method, "original_#{name}", name if sing.respond_to? name
        if block_given?
          sing.send :define_method, name, &block
        else
          # use eval instead of a block to work around a memory leak in dev
          # mode in fcgi
          # 下面的方法不能处理value=false/true的情况
          #sing.class_eval "def #{name}; #{value.to_s.inspect}; end"
          #sing.send :define_method, name, lambda{value.dup rescue value}
          sing.class_eval "def #{name}; #{(value==false||value==true)? value: value.inspect}; end"
        end
      end

      # 检查是否需要转换编码
      def transform_encoding?
        # 开启编码自动转换
        ActiveRecord::Base.set_auto_transform_encoding true unless ActiveRecord::Base.respond_to?(:auto_transform_encoding)
        ActiveRecord::Base.auto_transform_encoding && self.respond_to?(:table_charset) && self.respond_to?(:auto_transform_encoding) && self.auto_transform_encoding
      end
    end
  end
end