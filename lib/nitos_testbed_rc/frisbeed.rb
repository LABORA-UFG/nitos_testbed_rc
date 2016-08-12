#frisbee server
#created by parent :frisbee_factory
#used in load command

module OmfRc::ResourceProxy::Frisbeed
  include OmfRc::ResourceProxyDSL
  require 'omf_common/exec_app'

  @config = YAML.load_file('/etc/nitos_testbed_rc/frisbee_proxy_conf.yaml')
  # @config = YAML.load_file(File.join(File.dirname(File.expand_path(__FILE__)), '../etc/frisbee_proxy_conf.yaml'))
  @fconf = @config[:frisbee]

  register_proxy :frisbeed, :create_by => :frisbee_factory

  utility :common_tools
  utility :platform_tools

  property :app_id, :default => nil
  property :binary_path, :default => @fconf[:frisbeedBin]                 #binary path to frisbeed '/usr/sbin/frisbeed'
  property :map_err_to_out, :default => false

  property :multicast_interface, :default => @fconf[:multicastIF]         #multicast interface, example 10.0.0.200 (-i arguement)
  property :multicast_address, :default => @fconf[:mcAddress]             #multicast address, example 224.0.0.1 (-m arguement)
  property :port                                                          #port, example 7000 (-p arguement)
  property :speed, :default => @fconf[:bandwidth]                         #bandwidth speed in bits/sec, example 50000000 (-W arguement)
  property :image, :default => @fconf[:imageDir] + '/' + @fconf[:defaultImage]  #image to burn, example /var/lib/omf-images-5.4/baseline.ndz



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
    server.property.image = server.property.image.nil? ? @fconf[:imageDir] + '/' + @fconf[:defaultImage] : server.property.image
    server.property.image = server.property.image.start_with?('/') ? server.property.image : @fconf[:imageDir] + '/' + server.property.image
    unless File.file?(server.property.image)
      debug "File '#{server.property.image}' does not exist."
      Thread.new do
        sleep 1
        server.inform(:error, {
          event_type: 'ERROR',
          exit_code: -1,
          msg: "File '#{server.property.image}' does not exist."
        }, :ALL)
      end
      next
    end
    debug "Frisbee server is loading image: #{server.property.image}"

    @app = {} if @app.nil?

    @app[server.uid] = ExecApp.new(server.property.app_id, server.build_command_line, server.property.map_err_to_out) do |event_type, app_id, msg|
      server.process_event(server, event_type, app_id, msg)
    end
  end

  hook :before_release do |server|
    begin
      @app[server.uid].signal(signal = 'KILL') unless @app.nil?
    rescue Exception => e
      raise e unless e.message == "No such process"
    ensure
     $ports.delete_if {|x| x == server.property.port}
    end
  end

  # This method processes an event coming from the application instance, which
  # was started by this Resource Proxy (RP). It is a callback, which is usually
  # called by the ExecApp class in OMF
  #
  # @param [AbstractResource] res this RP
  # @param [String] event_type the type of event from the app instance
  #                 (STARTED, DONE.OK, DONE.ERROR, STDOUT, STDERR)
  # @param [String] app_id the id of the app instance
  # @param [String] msg the message carried by the event
  #
  def process_event(res, event_type, app_id, msg)
    logger.info "Frisbeed: App Event from '#{app_id}' - #{event_type}: '#{msg}'"
    if event_type == 'EXIT' #maybe i should inform you for every event_type.
      res.inform(:status, {
        status_type: 'FRISBEED',
        event: event_type.to_s.upcase,
        app: app_id,
        exit_code: msg,
        msg: msg
      }, :ALL)
    elsif event_type == 'STDOUT'
      res.inform(:status, {
        status_type: 'FRISBEED',
        event: event_type.to_s.upcase,
        app: app_id,
        exit_code: msg,
        msg: msg
      }, :ALL)
    end
  end

 # Build the command line, which will be used to add a new user.
  #
  work('build_command_line') do |res|
    cmd_line = "env -i " # Start with a 'clean' environment
    cmd_line += res.property.binary_path + " " # the /usr/sbin/frisbeed
    cmd_line += "-i " + res.property.multicast_interface + " " # -i for interface
    cmd_line += "-m " + res.property.multicast_address + " "   # -m for address
    cmd_line += "-p " + res.property.port.to_s  + " "           # -p for port
    cmd_line += "-W " + res.property.speed.to_s + " "           # -W for bandwidth
    cmd_line += res.property.image                              # image no arguement
    cmd_line
  end
end
