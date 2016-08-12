#frisbee client
#created by parent :frisbee_factory
#used in load command
require 'net/telnet'
require 'socket'
require 'timeout'

module OmfRc::ResourceProxy::Frisbee #frisbee client
  include OmfRc::ResourceProxyDSL
  require 'omf_common/exec_app'
  @config = YAML.load_file('/etc/nitos_testbed_rc/frisbee_proxy_conf.yaml')
  # @config = YAML.load_file(File.join(File.dirname(File.expand_path(__FILE__)), '../etc/frisbee_proxy_conf.yaml'))
  @fconf = @config[:frisbee]

  register_proxy :frisbee, :create_by => :frisbee_factory

  utility :common_tools
  utility :platform_tools

  property :app_id, :default => nil
  property :binary_path, :default => @fconf[:frisbeeBin]      #'/usr/sbin/frisbee'
  property :map_err_to_out, :default => false

  property :multicast_interface                               #multicast interface, example 10.0.1.12 for node12 (-i arguement)
  property :multicast_address, :default => @fconf[:mcAddress] #multicast address, example 224.0.0.1 (-m arguement)
  property :port                                              #port, example 7000 (-p arguement)
  property :hardrive, :default => "/dev/sda"                  #hardrive to burn the image, example /dev/sda (nparguement)
  property :node_topic                                        #the node

  hook :after_initial_configured do |client|
    Thread.new do
      sleep 1
      debug "Received message '#{client.opts.inspect}'"
      if error_msg = client.opts.error_msg
        client.inform(:error,{
          event_type: "AUTH",
          exit_code: "-1",
          node_name: client.property.node_topic,
          msg: error_msg
        }, :ALL)
        next
      end
      # if client.opts.ignore_msg
      #   #just ignore this message, another resource controller should take care of this message
      #   next
      # end
      # nod = {}
      # nod[:node_name] = client.opts.node.name
      # client.opts.node.interfaces.each do |i|
      #   if i[:role] == "control"
      #     nod[:node_ip] = i[:ip][:address]
      #     nod[:node_mac] = i[:mac]
      #   end
      # end
      # nod[:node_cm_ip] = client.opts.node.cmc.ip.address
      #nod = {node_name: "node1", node_ip: "10.0.0.1", node_mac: "00-03-1d-0d-4b-96", node_cm_ip: "10.0.0.101"}
      nod = client.opts.node
      client.property.multicast_interface = nod[:node_ip]
      client.property.app_id = client.hrn.nil? ? client.uid : client.hrn

      command = "#{client.property.binary_path} -i #{client.property.multicast_interface} -m #{client.property.multicast_address} -p #{client.property.port} #{client.property.hardrive}"
      debug "Executing command #{command} on host #{client.property.multicast_interface.to_s}"
      
      output = ''
      retry_flag = 0
      host = Net::Telnet.new("Host" => client.property.multicast_interface.to_s, "Timeout" => 200, "Prompt" => /[\w().-]*[\$#>:.]\s?(?:\(enable\))?\s*$/)
      while retry_flag < 2
        host.cmd(command.to_s) do |c|
          puts "$ #{c}"
          if c[0,8] ==  "Progress"
            c = c.split[1]
            client.inform(:status, {
              status_type: 'FRISBEE',
              event: "STDOUT",
              app: client.property.app_id,
              node: client.property.node_topic,
              msg: "#{c.to_s}"
            }, :ALL)
          elsif c[0,5] == "Wrote"
            c = c.split("\n")
            output = "#{c.first}\n#{c.last}"
          elsif c[0,6] == "\nWrote"
            c = c.split("\n")
            output = "#{c[1]}\n#{c.last}"
          elsif c.strip == "Short write!"
            client.inform(:error,{
              event_type: "ERROR",
              exit_code: "-1",
              node_name: client.property.node_topic,
              msg: "Load ended with 'Short write' error msg!"
            }, :ALL)
          end
        end
        break if output != ''
        retry_flag += 1
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
    # client.execute_frisbee
  end

  work('execute_frisbee') do |client|
    debug "Received message '#{client.opts.inspect}'"
    sleep 1
    if error_msg = client.opts.error_msg
      client.inform(:error,{
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

    command = "#{client.property.binary_path} -i #{client.property.multicast_interface} -m #{client.property.multicast_address} -p #{client.property.port} #{client.property.hardrive}"
    debug "Executing command #{command} on host #{client.property.multicast_interface.to_s}"
    
    output = ''
    host = Net::Telnet.new("Host" => client.property.multicast_interface.to_s, "Timeout" => 200, "Prompt" => /[\w().-]*[\$#>:.]\s?(?:\(enable\))?\s*$/)
    host.cmd(command.to_s) do |c|
      if c[0,8] ==  "Progress"
        c = c.split[1]
        client.inform(:status, {
          status_type: 'FRISBEE',
          event: "STDOUT",
          app: client.property.app_id,
          node: client.property.node_topic,
          msg: "#{c.to_s}"
        }, :ALL)
      elsif c[0,5] == "Wrote"
        c = c.split("\n")
        output = "#{c.first}\n#{c.last}"
      elsif c[0,6] == "\nWrote"
        c = c.split("\n")
        output = "#{c[1]}\n#{c.last}"
      elsif c.strip == "Short write!"
        client.inform(:error,{
          event_type: "ERROR",
          exit_code: "-1",
          node_name: client.property.node_topic,
          msg: "Load ended with 'Short write' error msg!"
        }, :ALL)
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
end
