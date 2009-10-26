module ActiveRecord
  module Associations
    class BelongsToAssociation
      private
      alias :origin_find_target :find_target
      def find_target
        @reflection.klass.find(:first,
          :conditions => construct_sql,
          :select     => @reflection.options[:select],
          #:order      => @reflection.options[:order],
          :include    => @reflection.options[:include],
          :readonly   => @reflection.options[:readonly]
        )
      end
      
      def construct_sql
        @finder_sql = "#{@reflection.quoted_table_name}.#{@reflection.primary_key_name} = #{owner_quoted_id}"
        @finder_sql << " AND (#{conditions})" if conditions
      end

      def owner_quoted_id
        if @reflection.options[:primary_key]
          @owner.class.quote_value(@owner.send(:read_attribute,@reflection.options[:primary_key]))
        else
          @owner.quoted_id
        end
      end
    end
  end
end