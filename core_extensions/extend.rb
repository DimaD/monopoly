#include all files in core_extension directory
dir_name = File.dirname(__FILE__)
Dir.new(dir_name).reject {|f| f =~ /^(\.|extend\.rb)/}.each {|f| require "#{dir_name}/#{f}"}
