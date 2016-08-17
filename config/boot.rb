require 'bundler/setup'
require 'yaml'
if RUBY_VERSION == 'java'
  require 'orientdb'
end
project_root = File.expand_path('../..', __FILE__)
require "#{project_root}/lib/active-orient.rb"

begin
  connect_file = File.expand_path('../../config/connect.yml', __FILE__)
  config_file = File.expand_path('../../config/config.yml', __FILE__)
  connectyml  = YAML.load_file( connect_file )[:orientdb][:admin] if connect_file.present?
  configyml  = YAML.load_file( config_file )[:active_orient] if config_file.present?
rescue Errno::ENOENT => e
  ActiveOrient::Base.logger = Logger.new('/dev/stdout')
  ActiveOrient::OrientDB.logger.error{ "config/connectyml not present"  }
  ActiveOrient::OrientDB.logger.error{ "Using defaults to connect database-server"  }

end

e=  ARGV.present? ? ARGV.last.downcase : 'development'
env =  if e =~ /^p/
	 'production'
       elsif e =~ /^t/
	 'test'
       else
	 'development'
       end
puts "Using #{env}-environment"
##in test-mode, always use ActiceOrient as Prefix for Model-classes
ActiveOrient::Model.namespace = if env == 'test'
				    Object
				else
				  n= configyml.present? ? configyml[:namespace] : :self
				  case n
				  when :self
				    ActiveOrient::Model
				  when :object
				    Object
				  when :active_orient
				    ActiveOrient
				  end
				end
databaseyml   = YAML.load_file( connect_file )[:orientdb][:database]
log_file =   if config_file.present?
	       dev = YAML.load_file( connect_file )[:orientdb][:logger]
	       if dev.blank? || dev== 'stdout'
		 '/dev/stdout'
	       else
		 project_root+'/log/'+env+'.log'
	       end
	     end


logger =  Logger.new log_file
logger.level = case env
	       when 'production' 
		 Logger::ERROR
	       when 'development'
		 Logger::WARN
	       else
		 Logger::INFO
	       end
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime("%d.%m.(%X)")}#{"%5s" % severity}->#{progname}:..:#{msg}\n"
end
ActiveOrient::Model.logger =  logger
ActiveOrient::OrientDB.logger =  logger
if connectyml.present? and connectyml[:user].present? and connectyml[:pass].present?
  ActiveOrient.default_server= { user: connectyml[:user], password: connectyml[:pass] ,
				 server: 'localhost', port: 2480  }
  ActiveOrient.database = @configDatabase.presence || databaseyml[env.to_sym]
  ORD = ActiveOrient::OrientDB.new  preallocate: true
  if RUBY_PLATFORM == 'java'
    DB =  ActiveOrient::API.new   preallocate: false
  else
    DB = ORD
  end

  # require model files after initializing the database
  require "#{project_root}/lib/model/edge.rb"
  require "#{project_root}/lib/model/vertex.rb"

  # thus the classes are predefined and modelfiles just extend the classes
  # make shure that E and V are required first => sort by length 
  models= Dir.glob(File.join( project_root, "model",'**', "*rb")).sort{|x,y| x.size <=> y.size }
  included_models = models.collect { |file| [file, require( file )] }
  if included_models.present? 
    puts "Included Models: "
    puts included_models.collect{|x,y| [ "\t",x.split("/").last , " \t-> " , y].join }.join("\n")
  else
    puts "No Model-classes defined"
  end
else
  ActiveOrient::Base.logger = Logger.new('/dev/stdout')
  ActiveOrient::OrientDB.logger.error{ "config/connectyml is  misconfigurated" }
  ActiveOrient::OrientDB.logger.error{ "Database Server is NOT available"} 
end



