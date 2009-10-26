require 'rails_generator/simple_logger'

namespace :tdm do
  desc "Apply patches of datanoise-actionwebservice-2.3.2 and magic_multi_connections-1.2.1"
  task :patch do 
    src_patch = File.expand_path(File.dirname(__FILE__) + '/../patches')
    des_patch = Gem.dir

    logger = Rails::Generator::SimpleLogger.new
    
    Dir.glob(File.join(src_patch,'*')).each do |path|
      next if File.file? path
      logger.patch "#{path.gsub(src_patch,'').delete('/')}"
      
      Dir.glob(File.join(path,'**/*')).each do |src_file|
        next unless File.file? src_file
      
        f = File.expand_path(src_file).gsub(src_patch,'')
        des_file = File.join(des_patch,'gems',f)

        des_dir = File.dirname des_file
        next unless File.exists? des_dir

        if File.exists? des_file
          if FileUtils.identical? des_file,src_file
            logger.identical des_file
            next
          end
          
          FileUtils.copy des_file,"#{des_file}.bak"
          FileUtils.copy src_file, des_file
          logger.force des_file
        else
          FileUtils.copy src_file, des_file
          logger.create des_file
        end
      end
    end
  end
end