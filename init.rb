# Include hook code here
require 'dblayer'
require 'tdmodel'
require 'magic_multi_connections'
require 'iconv'

$config_dir = File.join(RAILS_ROOT,"config/legacy_db")

begin
# 加载数据库配置
DBLayer::load_dbconfig(File.join($config_dir,"db.yml"))
DBLayer::extract_db_tables
DBLayer::save_db_tables
#DBLayer::save_linted_dbconfig

# 加载数据模型
DBLayer::load_dm_file(File.join($config_dir,"dm.yml"))
#DBLayer::save_linted_dm

# 为每个数据库创建用于数据库并发访问的模块
DBLayer::concurrent_multi_dbs

# 为数据模型中的每个数据表建立ORM
DBLayer::orm_dms.each do |dm|
    # 关闭数据库的单表继承功能
    dm.inheritance_column = ''
end
rescue =>err_info
  puts err_info
end

ActiveRecord::ConnectionAdapters::OracleAdapter.emulate_booleans = false