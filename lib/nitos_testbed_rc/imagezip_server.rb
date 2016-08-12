#Imagezip server
#created by parent :frisbee_factory
#used in save command

module OmfRc::ResourceProxy::ImagezipServer #Imagezip server
  include OmfRc::ResourceProxyDSL
  require 'omf_common/exec_app'

  @config = YAML.load_file('/etc/nitos_testbed_rc/frisbee_proxy_conf.yaml')
  # @config = YAML.load_file(File.join(File.dirname(File.expand_path(__FILE__)), '../etc/frisbee_proxy_conf.yaml'))
  @fconf = @config[:frisbee]

  register_proxy :imagezip_server, :create_by => :frisbee_factory

  utility :common_tools
  utility :platform_tools

  property :app_id, :default => nil
  property :binary_path, :default => @fconf[:imagezipServerBin] #usualy '/bin/nc'
  property :map_err_to_out, :default => false

  property :ip, :default => @fconf[:multicastIF]
  property :port
  property :image_name, :default => @fconf[:imageDir] + '/new_image.ndz'

  property :app, :default => nil

  hook :after_initial_configured do |server|
    debug "Received message '#{server.opts.inspect}'"
    # if error_msg = server.opts.error_msg
    #   next
    # end
    # if server.opts.ignore_msg
    #   #just ignore this message, another resource controller should take care of this message
    #   next
    # end
    server.property.app_id = server.hrn.nil? ? server.uid : server.hrn
    server.property.image_name = server.property.image_name.nil? ? @fconf[:imageDir] + '/' + @fconf[:defaultImage] : server.property.image_name
    server.property.image_name = server.property.image_name.start_with?('/') ? server.property.image_name : @fconf[:imageDir] + '/' + server.property.image_name

    @app = {} if @app.nil?

    @app[server.uid] = ExecApp.new(server.property.app_id, server.build_command_line, server.property.map_err_to_out) do |event_type, app_id, msg|
      server.process_event(server, event_type, app_id, msg)
    end
  end

  hook :before_release do |server|
    begin
      @app[server.uid].signal(signal = 'KILL') unless @app[server.uid].nil?
    rescue Exception => e
      raise e unless e.message == "No such process"
    ensure
      $ports.delete_if {|x| x == server.property.port}
    end
  end

  def process_event(res, event_type, app_id, msg)
      logger.info "ImagezipServer: App Event from '#{app_id}' - #{event_type}: '#{msg}'"
      if event_type == 'EXIT' #maybe i should inform you for every event_type, we'll see.
        res.inform(:status, {
          status_type: 'IMAGEZIP_SERVER',
          event: event_type.to_s.upcase,
          app: app_id,
          exit_code: msg,
          msg: msg
        }, :ALL)
      elsif event_type == 'STDOUT'
        res.inform(:status, {
          status_type: 'IMAGEZIP_SERVER',
          event: event_type.to_s.upcase,
          app: app_id,
          exit_code: msg,
          msg: msg
        }, :ALL)
      end
  end

  work('build_command_line') do |res|
    cmd_line = "env -i " # Start with a 'clean' environment
    cmd_line += res.property.binary_path + " "
    cmd_line += "-d -l " +  res.property.ip + " " + res.property.port.to_s + " > " +  res.property.image_name
    cmd_line
  end
end
