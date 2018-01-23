#Imagezip client
#created by parent :frisbee_factory
#used in save command

#$domain = @config[:domain][:ip]
require 'net/telnet'
require 'socket'
require 'timeout'

module OmfRc::ResourceProxy::ImagezipClient #Imagezip client
  include OmfRc::ResourceProxyDSL
  require 'omf_common/exec_app'

  @config = YAML.load_file('/etc/nitos_testbed_rc/frisbee_proxy_conf.yaml')
  # @config = YAML.load_file(File.join(File.dirname(File.expand_path(__FILE__)), '../etc/frisbee_proxy_conf.yaml'))
  @fconf = @config[:frisbee]

  register_proxy :imagezip_client, :create_by => :frisbee_factory

  utility :common_tools
  utility :platform_tools

  property :app_id, :default => nil
  property :binary_path, :default => @fconf[:imagezipClientBin] #usually '/usr/bin/imagezip'
  property :map_err_to_out, :default => false

  property :ip, :default => @fconf[:multicastIF]
  property :port
  property :hardrive, :default => "/dev/sda"
  property :node_topic

  hook :after_initial_configured do |client|
    Thread.new do
      debug "Received message '#{client.opts.inspect}'"
      sleep 1
      if error_msg = client.opts.error_msg
        res.inform(:error,{
          event_type: "AUTH",
          exit_code: "-1",
          node_name: client.property.node_topic,
          msg: error_msg
        }, :ALL)
        next
      end

      nod = client.opts.node
      client.property.multicast_interface = nod[:node_ip]
      client.property.app_id = client.hrn.nil? ? client.uid : client.hrn

      command = "#{client.property.binary_path} -o -z1 #{client.property.hardrive} - | #{@fconf[:imagezipClientNC]} #{client.property.ip} #{client.property.port}"
      debug "Executing command #{command} on host #{client.property.multicast_interface.to_s}"
      host = Net::Telnet.new("Host" => client.property.multicast_interface.to_s.strip, "Timeout" => false, "Telnetmode" => true, "Prompt" => /^\+OK/n)

      output = ''
      host.cmd(command.to_s) do |c|
        print "#{c}"
        if c.include? 'compressed'
          output = c
        end
      end

      client.inform(:status, {
        status_type: 'FRISBEE',
        event: "EXIT",
        app: client.property.app_id,
        node: client.property.node_topic,
        msg: output
      }, :ALL)
      host.close
    end

    # Thread.new do
    #   debug "Received message '#{client.opts.inspect}'"
    #   sleep 2
    #   if error_msg = client.opts.error_msg
    #     res.inform(:error,{
    #       event_type: "AUTH",
    #       exit_code: "-1",
    #       node_name: client.property.node_topic,
    #       msg: error_msg
    #     }, :ALL)
    #     next
    #   end
    #   # if client.opts.ignore_msg
    #   #   #just ignore this message, another resource controller should take care of this message
    #   #   next
    #   # end

    #   # nod = {}
    #   # nod[:node_name] = client.opts.node.name
    #   # client.opts.node.interfaces.each do |i|
    #   #   if i[:role] == "control"
    #   #     nod[:node_ip] = i[:ip][:address]
    #   #     nod[:node_mac] = i[:mac]
    #   #   elsif i[:role] == "cm_network"
    #   #     nod[:node_cm_ip] = i[:ip][:address]
    #   #   end
    #   # end
    #   # nod[:node_cm_ip] = client.opts.node.cmc.ip.address

    #   nod = client.opts.node
    #   client.property.app_id = client.hrn.nil? ? client.uid : client.hrn

    #   command = "#{client.property.binary_path} -o -z1 -d -d #{client.property.hardrive} - | #{@fconf[:imagezipClientNC]} -q 0 #{client.property.ip} #{client.property.port}"
    #   #     nod = {node_name: "node1", node_ip: "10.0.0.1", node_mac: "00-03-1d-0d-4b-96", node_cm_ip: "10.0.0.101"}
    #   summary = ''
    #   debug "Telnet on: '#{nod[:node_ip]}'"
    #   host = Net::Telnet.new("Host" => nod[:node_ip], "Timeout" => 200, "Prompt" => /[\w().-]*[\$#>:.]\s?(?:\(enable\))?\s*$/)#, "Prompt" => /[\w().-]*[\$#>:.]\s?(?:\(enable\))?\s*$/)
    #   debug "Telnet successfull"
    #   debug "Executing command #{command.to_s}"
    #   host.cmd(command.to_s) do |c|
    #     print "#{c}"
    #     # if c.to_s !=  "\n" && c[0,5] != "\n/usr" && c.to_s != "." && c.to_s != ".." && c.to_s != "..."
    #       # puts '---------(' + c.to_s + ')-----------'
    #     if c.include? 'compressed'
    #       summary = c
    #       # client.inform(:status, {
    #       #   status_type: 'IMAGEZIP',
    #       #   event: "STDOUT",
    #       #   app: client.property.app_id,
    #       #   node: client.property.node_topic,
    #       #   msg: "#{c.to_s}"
    #       # }, :ALL)
    #     end
    #   end
    #   debug "imagezip client finished"

    #   client.inform(:status, {
    #     status_type: 'IMAGEZIP',
    #     event: "EXIT",
    #     app: client.property.app_id,
    #     node: client.property.node_topic,
    #     msg: summary
    #   }, :ALL)
    #   host.close
    # end
  end
end
