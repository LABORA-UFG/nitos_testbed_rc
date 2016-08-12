#this resource is used to control applications frisbee/frisbeed and imagezip_server/imagezip_client.

$ports = []
module OmfRc::ResourceProxy::FrisbeeFactory
  include OmfRc::ResourceProxyDSL

  @config = YAML.load_file('/etc/nitos_testbed_rc/frisbee_proxy_conf.yaml')
  # @config = YAML.load_file(File.join(File.dirname(File.expand_path(__FILE__)), '../etc/frisbee_proxy_conf.yaml'))
  @fconf = @config[:frisbee]

  register_proxy :frisbee_factory

  request :ports do |res|
    port = @fconf[:startPort]
    loop do
      if $ports.include?(port)
        port +=1
      elsif !res.port_open?(port)
        port +=1
      else
        $ports << port
        break
      end
    end
    debug "port chosen: '#{port}'"
    port
  end

  def port_open?(port, seconds=1)
    Timeout::timeout(seconds) do
      begin
        serv = TCPServer.new('localhost', port) 
        serv.close
        return true
      rescue 
        return false
      end
    end
  rescue Timeout::Error
    return false
  end
end
