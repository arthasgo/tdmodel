module ActiveRecord
  module Associations
    class HasManyAssociation
      protected
        alias :origin_owner_quoted_id :owner_quoted_id
        def owner_quoted_id
          if @reflection.options[:primary_key]
            #@owner.class.quote_value(@owner.send(@reflection.options[:primary_key]))
            @owner.class.quote_value(@owner.send(:read_attribute,@reflection.options[:primary_key]))
          else
            @owner.quoted_id
          end
        end
    end
  end
end