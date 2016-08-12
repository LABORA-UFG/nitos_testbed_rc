#this resource is used to control chassis managers.
require 'rubygems'
require 'yaml'
require 'open-uri'
require 'nokogiri'
require 'net/ssh'

REBOOT_CMD = "reboot"
SHUTDOWN_CMD = "shutdown -P now"

module OmfRc::ResourceProxy::CM
  include OmfRc::ResourceProxyDSL

  @config = YAML.load_file('/etc/nitos_testbed_rc/cm_proxy_conf.yaml')
  # @config = YAML.load_file(File.join(File.dirname(File.expand_path(__FILE__)), '../etc/cm_proxy_conf.yaml'))
  @@timeout = @config[:timeout]

  register_proxy :cm, :create_by => :cm_factory

  property :node, default: "node000"

  hook :after_initial_configured do |res|
    puts "*******************************************"
    puts "Node: #{res.property.node}"
    puts "*******************************************"
  end

  configure :state do |res, value|
    debug "Received message '#{value.inspect}'"
    if error_msg = value.error_msg
      res.inform(:error,{
        event_type: "AUTH",
        exit_code: "-1",
        node_name: value[:node],
        msg: error_msg
      }, :ALL)
      next
    end
    nod = value.node
    # nod = {node_name: "node120", node_ip: "10.0.1.120", node_mac: "00-03-1d-0d-4b-96", node_cm_ip: "10.1.0.120"} if value.node == 'node120'
    # nod = {node_name: "node121", node_ip: "10.0.1.121", node_mac: "00-03-1d-0d-40-98", node_cm_ip: "10.1.0.121"} if value.node == 'node121'

    case value[:status].to_sym
    when :on then res.start_node(nod, value[:wait])
    when :off then res.stop_node(nod, value[:wait])
    when :reset then res.reset_node(nod, value[:wait])
    when :start_on_pxe then res.start_node_pxe(nod)
    when :start_without_pxe then res.start_node_pxe_off(nod, value[:last_action])
    when :get_status then res.status(nod)
    else
      res.log_inform_warn "Cannot switch node to unknown state '#{value[:status].to_s}'!"
    end
  end

  #this is used by the get status call
  work("status") do |res, node|
    debug "Status url: http://#{node[:node_cm_ip].to_s}/state"
    begin
      resp = open("http://#{node[:node_cm_ip].to_s}/state")
    rescue
      res.inform(:error, {
        event_type: "HTTP",
        exit_code: "-1",
        node_name: "#{node[:node_name].to_s}",
        msg: "failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
      }, :ALL)
      next
    end
    ans = res.parse_responce(resp, "//Response//line//value")

    res.inform(:status, {
      current: "#{ans}",
      node_name: "#{node[:node_name].to_s}"
    }, :ALL)
    sleep 1 #this solves the getting stuck problem.
  end

  work("start_node") do |res, node, wait|
    node[:node_mac] = node[:node_mac].downcase.gsub(/:/, '-')
    symlink_name = "/tftpboot/pxelinux.cfg/01-#{node[:node_mac]}"
    if File.exists?(symlink_name)
      File.delete(symlink_name)
    end
    debug "Start_node url: http://#{node[:node_cm_ip].to_s}/on"
    begin
      resp = open("http://#{node[:node_cm_ip].to_s}/on")
    rescue
      res.inform(:error, {
        event_type: "HTTP",
        exit_code: "-1",
        node_name: "#{node[:node_name].to_s}",
        msg: "#{node[:name]} failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
      }, :ALL)
      next
    end

    ans = res.parse_responce(resp, "//Response")

    if ans == 'ok'
      res.inform(:status, {
        node_name: "#{node[:node_name].to_s}",
        current: :booting,
        desired: :running
      }, :ALL)
    elsif ans == 'already on'
      res.inform(:status, {
        node_name: "#{node[:node_name].to_s}",
        current: :running,
        desired: :running
      }, :ALL)
    end

    if wait
      if res.wait_until_ping(node[:node_ip])
        res.inform(:status, {
          node_name: "#{node[:node_name].to_s}",
          current: :running,
          desired: :running
        }, :ALL)
      else
        res.inform(:error, {
          event_type: "TIME_OUT",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "Node '#{node[:node_name].to_s}' timed out while booting."
        }, :ALL)
      end
    end
    sleep 1
  end

  work("stop_node") do |res, node, wait|
    node[:node_mac] = node[:node_mac].downcase.gsub(/:/, '-')
    symlink_name = "/tftpboot/pxelinux.cfg/01-#{node[:node_mac]}"
    if File.exists?(symlink_name)
      File.delete(symlink_name)
    end
    begin
      debug "Shutting down node '#{node[:node_name]}' through ssh."
      raise "lte" if node[:name].start_with("e_node_b")
      ssh = Net::SSH.start(node[:node_ip], 'root')#, :password => @password)
      resp = ssh.exec!(SHUTDOWN_CMD)
      ssh.close
      debug "shutting down completed with ssh."
      res.inform(:status, {
          node_name: "#{node[:node_name].to_s}",
          current: :running,
          desired: :stopped
      }, :ALL)
    rescue
      begin
        debug "ssh failed, using CM card instead."
        debug "Stop_node url: http://#{node[:node_cm_ip].to_s}/off"

        begin
          resp = open("http://#{node[:node_cm_ip].to_s}/off")
        rescue
          res.inform(:error, {
            event_type: "HTTP",
            exit_code: "-1",
            node_name: "#{node[:node_name].to_s}",
            msg: "#{node[:name]} failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
          }, :ALL)
          next
        end

        ans = res.parse_responce(resp, "//Response")

        if ans == 'ok'
          res.inform(:status, {
              node_name: "#{node[:node_name].to_s}",
              current: :running,
              desired: :stopped
          }, :ALL)
        elsif ans == 'already off'
          res.inform(:status, {
              node_name: "#{node[:node_name].to_s}",
              current: :stopped,
              desired: :stopped
          }, :ALL)
        end
      rescue
        res.inform(:error, {
          event_type: "HTTP",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
        }, :ALL)
        next
      end
    end

    if wait
      if res.wait_until_no_ping(node[:node_ip])
        res.inform(:status, {
          node_name: "#{node[:node_name].to_s}",
          current: :stopped,
          desired: :stopped
        }, :ALL)
      else
        res.inform(:error, {
          event_type: "TIME_OUT",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "Node '#{node[:node_name].to_s}' timed out while shutting down."
        }, :ALL)
      end
    end
    sleep 1
  end

  work("reset_node") do |res, node, wait|
    node[:node_mac] = node[:node_mac].downcase.gsub(/:/, '-')
    symlink_name = "/tftpboot/pxelinux.cfg/01-#{node[:node_mac]}"
    if File.exists?(symlink_name)
      File.delete(symlink_name)
    end
    begin
      debug "Rebooting node '#{node[:node_name]}' through ssh."
      ssh = Net::SSH.start(node[:node_ip], 'root')#, :password => @password)
      resp = ssh.exec!(REBOOT_CMD)
      ssh.close
      debug "Rebooting completed with ssh."
      res.inform(:status, {
          node_name: "#{node[:node_name].to_s}",
          current: :running,
          desired: :resetted
      }, :ALL)
    rescue
      begin
        debug "ssh failed, using CM card instead."
        debug "Reset_node url: http://#{node[:node_cm_ip].to_s}/reset"
        begin
          resp = open("http://#{node[:node_cm_ip].to_s}/reset")
        rescue
          res.inform(:error, {
            event_type: "HTTP",
            exit_code: "-1",
            node_name: "#{node[:node_name].to_s}",
            msg: "#{node[:name]} failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
          }, :ALL)
          next
        end

        ans = res.parse_responce(resp, "//Response")
        if ans == 'ok'
          res.inform(:status, {
              node_name: "#{node[:node_name].to_s}",
              current: :resetted,
              desired: :resetted
          }, :ALL)
        end
      rescue
        res.inform(:error, {
          event_type: "HTTP",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
        }, :ALL)
        next
      end
    end

    if wait
      if res.wait_until_ping(node[:node_ip])
        res.inform(:status, {
            node_name: "#{node[:node_name].to_s}",
            current: :resetted,
            desired: :resetted
        }, :ALL)
      else
        res.inform(:error, {
          event_type: "TIME_OUT",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "Node '#{node[:node_name].to_s}' timed out while reseting."
        }, :ALL)
      end
    end
    sleep 1
  end

  work("start_node_pxe") do |res, node|
    resp = res.get_status(node)
    node[:node_mac] = node[:node_mac].downcase.gsub(/:/, '-')
    if resp == :on
      symlink_name = "/tftpboot/pxelinux.cfg/01-#{node[:node_mac]}"
      if !File.exists?("#{symlink_name}")
        File.symlink("/tftpboot/pxelinux.cfg/#{@config[:pxeSymLinkConfFile]}", "#{symlink_name}")
      end
      debug "Start_node_pxe RESET: http://#{node[:node_cm_ip].to_s}/reset"
      begin
        open("http://#{node[:node_cm_ip].to_s}/reset")
      rescue
        res.inform(:error, {
          event_type: "HTTP",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
        }, :ALL)
        next
      end
    elsif resp == :off
      symlink_name = "/tftpboot/pxelinux.cfg/01-#{node[:node_mac]}"
      if !File.exists?("#{symlink_name}")
        File.symlink("/tftpboot/pxelinux.cfg/#{@config[:pxeSymLinkConfFile]}", "#{symlink_name}")
      end
      debug "Start_node_pxe ON: http://#{node[:node_cm_ip].to_s}/on"
      begin
        open("http://#{node[:node_cm_ip].to_s}/on")
      rescue
        res.inform(:error, {
          event_type: "HTTP",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
        }, :ALL)
        next
      end
    elsif resp == :started_on_pxe
      debug "Start_node_pxe STARTED: http://#{node[:node_cm_ip].to_s}/reset"
      begin
        open("http://#{node[:node_cm_ip].to_s}/reset")
      rescue
        res.inform(:error, {
          event_type: "HTTP",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
        }, :ALL)
        next
      end
    end

    if res.wait_until_ping(res, node[:node_ip])
      res.inform(:status, {
        node_name: "#{node[:node_name].to_s}",
        current: :pxe_on,
        desired: :pxe_on
      }, :ALL)
    else
      node[:node_mac] = node[:node_mac].downcase.gsub(/:/, '-')
      symlink_name = "/tftpboot/pxelinux.cfg/01-#{node[:node_mac]}"
      if File.exists?(symlink_name)
        File.delete(symlink_name)
      end
      res.inform(:error, {
        event_type: "TIME_OUT",
        exit_code: "-1",
        node_name: "#{node[:node_name].to_s}",
        msg: "Node '#{node[:node_name].to_s}' timed out while trying to boot on PXE."
      }, :ALL)
    end
    sleep 1
  end

  work("start_node_pxe_off") do |res, node, action|
    node[:node_mac] = node[:node_mac].downcase.gsub(/:/, '-')
    symlink_name = "/tftpboot/pxelinux.cfg/01-#{node[:node_mac]}"
    if File.exists?(symlink_name)
      File.delete(symlink_name)
    end
    if action == "reset"
      debug "Start_node_pxe_off RESET: http://#{node[:node_cm_ip].to_s}/reset"
      begin
        open("http://#{node[:node_cm_ip].to_s}/reset")
      rescue
        res.inform(:error, {
          event_type: "HTTP",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
        }, :ALL)
        next
      end

      t = 0
      if res.wait_until_ping(node[:node_ip])
        res.inform(:status, {
          node_name: "#{node[:node_name].to_s}",
          current: :pxe_off,
          desired: :pxe_off
        }, :ALL)
      else
        res.inform(:error, {
          event_type: "TIME_OUT",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "Node '#{node[:node_name].to_s}' timed out while booting."
        }, :ALL)
      end
    elsif action == "shutdown"
      debug "Start_node_pxe_off SHUTDOWN: http://#{node[:node_cm_ip].to_s}/off"
      begin
        open("http://#{node[:node_cm_ip].to_s}/off")
      rescue
        res.inform(:error, {
          event_type: "HTTP",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "failed to reach cm, ip: #{node[:node_cm_ip].to_s}."
        }, :ALL)
        next
      end

      if res.wait_until_no_ping(node[:node_ip])
        res.inform(:status, {
          node_name: "#{node[:node_name].to_s}",
          current: :pxe_off,
          desired: :pxe_off
        }, :ALL)
      else
        res.inform(:error, {
          event_type: "TIME_OUT",
          exit_code: "-1",
          node_name: "#{node[:node_name].to_s}",
          msg: "Node '#{node[:node_name].to_s}' timed out while shutting down."
        }, :ALL)
      end
    end
    sleep 1
  end

  #this is used by other methods in this scope
 def wait_until_ping(res, ip)
    t = 0
    resp = false
    loop do
      sleep 2
      status = system("ping #{ip} -c 2 -w 2")
      if t < @@timeout
        if status == true
          resp = true
          break
        end
      else
        resp = false
        break
      end
      t += 2
    end
    resp
  end

  #this is used by other methods in this scope
  work("wait_until_no_ping") do |res, ip|
    t = 0
    resp = false
    loop do
      sleep 2
      status = system("ping #{ip} -c 2 -w 2")
      if t < @@timeout
        if status == false
          resp = true
          break
        end
      else
        resp = false
        break
      end
      t += 2
    end
    resp
  end

  #this is used by other methods in this scope
  work("get_status") do |res, node|
    debug "http://#{node[:node_cm_ip].to_s}/state"
    resp = open("http://#{node[:node_cm_ip].to_s}/state")
    resp = res.parse_responce(resp, "//Response//line//value")
    debug "state response: #{resp}"

    if resp == 'on'
      symlink_name = "/tftpboot/pxelinux.cfg/01-#{node[:node_mac]}"
      if File.exists?("#{symlink_name}")
        :on_pxe
      else
        :on
      end
    elsif resp == 'off'
      :off
    end
  end

  work("parse_responce") do |res, input, path|
    input = input.string if input.kind_of? StringIO
    if input[0] == "<"
      output = Nokogiri::XML(input).xpath(path).text.strip
    else
      output = input.strip
    end
    output
  end
end