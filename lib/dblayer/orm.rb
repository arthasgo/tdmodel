module DBLayer
  class << self
    # # 为数据模型中的每个数据表建立ORM
    def orm_dms
      dms = @dm_with_full_tbls['models'].collect do |tbl,definition|
        orm tbl
      end
      dms
    end
    def orm(table_name)
      model_class = class_name_from_table(table_name)
      #see if it has already been defined
      const_missing(model_class)
    rescue NameError
      define_klass(table_name)
    end

    def objeck(table_name)
      orm(table_name).new
    end

    private
    def class_name_from_table(table_name)
      #table_name.camelize
      table_name.classify
    end

    def define_klass(table_name)
      begin
        if @dm_with_full_tbls['models'][table_name]
          define_model_with_relation table_name
        else
          define_default_model table_name
        end
      rescue =>err_info
        puts "error: on #{table_name} orm: #{err_info}"
      end
    end

    def define_model_with_relation(table_name)
      # 获取数据表关系
      model = @dm_with_full_tbls['models'][table_name]
      #raise "associations should be array" if model['associations'].class != "Array"

      # 生成数据表关系代码
      relation_code = []
      model['associations'].each do |asso|
        relation_opts = []

        # 提取数据表关系选项
        options = asso['options']
        if options
          options.each do |opt, val|
            relation_opts << ":#{opt}=>:#{val}"
          end
        end

        asso.delete('options')

        opts_code = relation_opts.join(',')
        asso.each do |tbl, relation|
          asso_model = class_name_from_table(tbl).underscore
          case relation
          when 'has_many'
            association_id = asso_model.pluralize
          when 'has_and_belongs_to_many'
            association_id = asso_model.pluralize
          else 
            association_id = asso_model
          end
          
          relation_code << (opts_code.empty? ? "#{relation} :#{association_id}" : "#{relation} :#{association_id}, #{opts_code}")
        end
      end

      primary_key = model['primary_key']? "set_primary_key('#{model['primary_key']}')" : "\n"
      sequence_name = model['sequence_name']? "set_sequence_name('#{model['sequence_name']}')" : "\n"
      physical_tbl= model['physical_tbl']

      model_class = class_name_from_table(table_name)
      db = @db_tbls[:tables][physical_tbl]
      db_config = @dbs[db] || {}
      encoding = db_config['encoding'] || 'utf8'
      class_def = <<-end_eval
           class #{model_class} < ActiveRecord::Base
             db_config = #{db_config.inspect}
             establish_connection db_config unless db_config.empty?
             set_table_name('#{physical_tbl}')
             set_table_charset('#{encoding}')
             #{primary_key}
             #{sequence_name}
             #{relation_code.join("    \n")}
           end
      end_eval

      eval(class_def, TOPLEVEL_BINDING)
      const_get(model_class)
    end

    def define_default_model(table_name)
      db = @db_tbls[:tables][table_name]
      db_config = @dbs[db] || {}

      model_class = class_name_from_table(table_name)
      Object.class_eval <<-end_eval
           class #{model_class} < ActiveRecord::Base
             db_config = #{db_config.inspect}
             establish_connection db_config unless db_config.empty?
             set_table_name('#{table_name}')
           end
      end_eval

      model_class.constantize
    end
  end
end
