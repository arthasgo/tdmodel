# To change this template, choose Tools | Templates
# and open the template in the editor.

module DBLayer
  class << self
    ValidRelations = ['has_one','has_many','has_and_belongs_to_many', 'belongs_to']
    
    # 加载表关系文件，并自动处理has_one/has_many, 与belongs_to成对问题
    def load_dm_file(dm_file)
      @dm_file = dm_file
      @config_dir = File.dirname(dm_file)
      
      load_dbtable_file

      build_full_models_with_reverse_associations dm_file
    end

    # 自动创建反转关联的数据表定义
    def build_full_models_with_reverse_associations(dm_file)
      origin_dm = YAML::load_file dm_file

      # 自动重建拥有、属于的表
      @dm_with_full_tbls = {'models'=>{}}
      
      # 检查表格式
      # 检查是否定义跟节点models
      unless origin_dm['models']
        puts "error: can't find the root 'models' in #{dm_file}"
        return @dm_with_full_tbls
      end

      # 检查models的值是否是hash
      unless origin_dm['models'].is_a? Hash
        puts "error: the 'models' should be a hash in #{dm_file}, but got a #{origin_dm['models'].class}"
        return @dm_with_full_tbls
      end
      
      # 数据表是否存在，配置是否正确
      origin_dm['models'].each do |tbl_name, tbl_definition|
        tbl_name = tbl_name.downcase

        # 检查数据表是否存在
        physical_tbl = tbl_name
        unless @db_tbls[:tables].has_key? tbl_name
          # 检查分表
          division_tbls = @db_tbls[:tables].keys.select {|tbl_item| tbl_item=~/^#{tbl_name}_*[0-9]*$/}
          if division_tbls.empty?
            puts "error: can't find database table '#{tbl_name}' in #{dm_file}, may be misspelt?"
            next
          end
          physical_tbl = division_tbls.sort.first
        end

        # 检查数据表不需要定义主键
        #unless tbl_definition.has_key? "primary_key"
        #  puts "warning: can't find primary_key for table '#{tbl_name}' in #{dm_file}"
        #next
        #end
        
        # 检查关联关系
        associations = tbl_definition['associations']
        unless associations && associations.is_a?(Array)
          puts "error: can't find associations for '#{tbl_name}', should be a array, but got a #{associations.class}" unless associations.is_a? Array
          next
        end

        # 保存数据表
        @dm_with_full_tbls['models'][tbl_name] ||= {}
        merge_model_definition! @dm_with_full_tbls['models'][tbl_name], tbl_definition
        @dm_with_full_tbls['models'][tbl_name]["physical_tbl"] = physical_tbl
        
        # 创建反转关联的数据表
        next unless tbl_definition["associations"]
        associations.each do |asso|
          asso_opt = asso['options'] || {}
          asso.delete('options')

          # 获取关联表
          asso.each do |asso_tbl,relation|
            # 检查关联数据表是否存在
            physical_tbl = asso_tbl
            unless @db_tbls[:tables].has_key? asso_tbl
              # 检查分表
              division_tbls = @db_tbls[:tables].keys.select {|tbl_item| tbl_item=~/^#{asso_tbl}_*[0-9]*$/}
              if division_tbls.empty?
                puts "error: can't find database table '#{asso_tbl}' in #{dm_file}, may be misspelt?"
                next
              end
              physical_tbl = division_tbls.sort.first
            end

            reverse_relation = {'has_one'=>'belongs_to','has_many'=>'belongs_to','has_and_belongs_to_many'=>'has_and_belongs_to_many'}
            # 创建反转关联的数据表
            case relation
            when /^has_one|has_many|has_and_belongs_to_many$/
              # 创建反转关联
              @dm_with_full_tbls['models'][asso_tbl] ||= {}
              reverse_asso_tbl_definition = reverse_asso_tbl_definition tbl_name,asso_opt,reverse_relation[relation]
              
              merge_model_definition! @dm_with_full_tbls['models'][asso_tbl], reverse_asso_tbl_definition
              @dm_with_full_tbls['models'][asso_tbl]["physical_tbl"] = physical_tbl
              
            when 'belongs_to'
              # 合并数据表选项
              @dm_with_full_tbls['models'][tbl_name] ||= {}
              merge_model_definition! @dm_with_full_tbls['models'][tbl_name], tbl_definition

              # 根据belongs_to是无法创建has_one，has_many关联的，所以主表一定要定义
              unless origin_dm['models'].has_key? asso_tbl
                puts "error: '#{tbl_name}' belongs_to '#{asso_tbl}', but can't find definition of #{asso_tbl}"
                
                @dm_with_full_tbls['models'].delete tbl_name
              end
            else
              puts "waring: invalid relation type '#{relation}' of #{tbl_name}, should be #{ValidRelations.join(',')}"

              @dm_with_full_tbls['models'].delete tbl_name
            end
          end
          
        end #end of associations.each

      end# end of origin_dm['models']

      # 返回数据模型
      @dm_with_full_tbls
    end

    # 保存lint之后的数据模型文件
    def save_linted_dm(dm_file='')
      unless @dm_with_full_tbls
        if File.exist(dm_file)
          load_dm_file dm_file
        else
          puts "can't find dm file '#{dm_file}'"
          return
        end
      end

      linted_file = File.join @config_dir,'ldm_linted.yml'
      File.open(linted_file, 'wb') {|f| f.write(@dm_with_full_tbls.to_yaml) }
    end

    private
    # 合并模型定义
    def merge_model_definition!(origin_model,new_model)
      new_model = new_model.deep_clone
      
      # 合并数据表选项
      new_model.each do |opt,val|
        case val
        when Hash
          origin_model[opt] ||= {}
          origin_model[opt].merge! val
        when Array
          # associations是数组，合并她
          origin_model[opt] ||= []
          origin_model[opt].concat(val)

          # 删除重复的
          uniq_arr = {:arr=>[],:arr_inspect=>[]}
          origin_model[opt].inject(uniq_arr) do |uniq_arr,e|
            e_insepct = e.inspect
            unless uniq_arr[:arr_inspect].include? e_insepct
              uniq_arr[:arr]<< e
              uniq_arr[:arr_inspect]<< e_insepct
            end

            uniq_arr
          end

          origin_model[opt] = uniq_arr[:arr]
        else
          # primary_key 是字符串，替换她
          origin_model[opt] = val
        end
      end

    end

    # 生成反转关联选项
    def reverse_asso_tbl_definition(tbl_name,asso_opt,relation)
      revser_tbl_definition = {'associations'=>[]}
      reverse_asso = {tbl_name=>relation}
      
      # 创建反转关联
      reverse_asso_opt={}
      copy_opts = [:foreign_key,:primary_key] # 需要复制的选项
      reverse_key = {:foreign_key=>:primary_key,:primary_key=>:foreign_key}
      if asso_opt
        asso_opt.each do |opt,val|
          reverse_asso_opt[reverse_key[opt]] = val if copy_opts.include? opt
        end
      end
      
      reverse_asso['options'] = reverse_asso_opt unless reverse_asso_opt.empty?
      
      revser_tbl_definition['associations'] << reverse_asso
      
      revser_tbl_definition
    end
  end
end
