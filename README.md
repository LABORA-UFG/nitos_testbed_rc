Nitos Testbed resource controllers (NTRC)
=================

Contains:

- Frisbee resource controller which conrols frisbee and imagezip in order to
save and load images to nodes.

- CM resource controller which controls chassis managers on nodes.

- User resource controller which administers users.

- om6 script which orchistrates the above.

These tools are under development. Unpredictable behaviour is to be expected untill
a stable version is provided.

Installation
------------

First you need to install the gem
  
    % gem install nitos_testbed_rc --pre

Then you need to run the install_ntrc script to generate the configuration files.

    % install_ntrc

Create certificates
-------------------

Use omf_cert.rb script to generate the following certificates and place them on directories '/root/.omf' and /root/.omf.

    % mkdir /root/.omf
    % mkdir /root/.omf/trusted_roots
    % cd /root/.omf

Create a root certificate (change DOMAIN).
Importand!!! If you already have a root certificate (probably created while installing omf_sfa) DO NOT create this certificate again and use the old one instead.

    % ruby omf_cert.rb --email root@DOMAIN -o /root/.omf/trusted_roots/root.pem --duration 5000000 create_root

Create a certificate for user_proxy of NTRC (change DOMAIN, XMPP_DOMAIN and if you wish the output file names).

    % ruby omf_cert.rb -o user_factory.pem --email user_factory@DOMAIN --resource-type user_factory --resource-id xmpp://user_factory@XMPP_DOMAIN --root /root/.omf/trusted_roots/root.pem --duration 50000000 create_resource

Create a certificate for cm_proxy of NTRC (change DOMAIN, XMPP_DOMAIN and if you wish the output file names).

    % ruby omf_cert.rb -o cm_factory.pem --email cm_factory@DOMAIN --resource-type cm_factory --resource-id xmpp://cm_factory@XMPP_DOMAIN --root /root/.omf/trusted_roots/root.pem --duration 50000000 create_resource

Create a certificate for frisbee_proxy of NTRC (change DOMAIN, XMPP_DOMAIN and if you wish the output file names).

    % ruby omf_cert.rb -o frisbee_factory.pem --email frisbee_factory@DOMAIN --resource-type frisbee_factory --resource-id xmpp://frisbee_factory@XMPP_DOMAIN --root /root/.omf/trusted_roots/root.pem --duration 50000000 create_resource

Create a certificate for the omf6 script, this certificate is inside the directory '~/.omf', every user of the testbed should have his own certificate in order to use omf6 script (change DOMAIN, USERNAME and if you wish the output file names).

    % ./omf_cert.rb -o user_cert.pem --email root@DOMAIN --user root --root ~/.omf/trusted_roots/root.pem --duration 50000000 --geni_uri URI:urn:publicid:IDN+DOMAIN+user+USERNAME create_user

Configuration files
-------------------

Change configuration file '/etc/nitos_testbed/user_proxy_conf.yaml', which is related to user_proxy of NTRC. For example:

    #xmpp details
    :xmpp:
      :username: user_proxy
      :password: pw
      :server: DOMAIN
    #x509 certificates to be used by user_proxy
    :auth:
      :root_cert_dir: ~/.omf/trusted_roots
      :entity_cert: ~/.omf/user_factory.pem
      :entity_key: ~/.omf/user_factory.pkey
    #operation mode for OmfCommon.init (development, production, etc)
    :operationMode: development 

Change configuration file '/etc/nitos_testbed/cm_proxy_conf.yaml', which is related to cm_proxy of NTRC. For example:

    #details to be used for the connection to the xmpp server
    :xmpp:
      :username: cm_proxy
      :password: pw
      :server: DOMAIN
    #x509 certificates to be used by cm_proxy
    :auth:
      :root_cert_dir: ~/.omf/trusted_roots
      :entity_cert: ~/.omf/cm_factory.pem
      :entity_key: ~/.omf/cm_factory.pkey

    #time (in seconds) before timeout error occurs
    :timeout: 80
    #operation mode for OmfCommon.init (development, production, etc)
    :operationMode: development
    #testbed xmpp topic
    :testbedTopic: am_controller

Change configuration file '/etc/nitos_testbed/frisbee_proxy_conf.yaml', which is related to frisbee_proxy of NTRC. For example:
    
    #xmpp details
    :xmpp:
      :username: frisbee_proxy
      :password: pw
      :server: DOMAIN
    #x509 certificates to be used by user_proxy
    :auth:
      :root_cert_dir: ~/.omf/trusted_roots
      :entity_cert: ~/.omf/frisbee_factory.pem
      :entity_key: ~/.omf/frisbee_factory.pkey

    #operation Mode for OmfCommon.init (development, production, etc)
    :operationMode: development

    #testbed xmpp topic
    :testbedTopic: am_controller

    #frisbee and imagezip configuration
    :frisbee:
      # Directory images are stored
      :imageDir: /var/lib/omf-images-6
      #defaultImage: orbit-baseline
      :defaultImage: baseline.ndz

      # max bandwidth for frisbee server
      :bandwidth: 50000000

      # Multicast address to use for servicing images
      #mcAddress: 224.0.0.2
      :mcAddress: 224.0.0.1
      # Using ports starting at ...
      :startPort: 7000

      # Time out frisbee server if nobody requested it within TIMEOUT sec
      :timeout: 3600

      # Directory to find frisbee daemons
      :frisbeedBin: /usr/sbin/frisbeed
      :frisbeeBin: /usr/sbin/frisbee
      :imagezipClientBin: /usr/bin/imagezip
      :imagezipServerBin: /bin/nc

      # Local interface to bind to for frisbee traffic
      #multicastIF: 192.168.204.1
      :multicastIF: 10.0.1.200

Change configuration file '~/.omf/etc/user_proxy_conf.yaml', which is related to omf6 script of NTRC, every user of the testbed should have his own configuration file in order to use omf6 script. For example:

    :xmpp:
      :script_user: script_user
      :password: pw
      :server: DOMAIN
    :auth:
      :root_cert_dir: ~/.omf/trusted_roots
      :entity_cert: ~/.omf/user_cert.pem
      :entity_key: ~/.omf/user_cert.pkey
    #operation mode for OmfCommon.init (development, production, etc)
    :operationMode: development
    #omf script configuration
    :omf_script:
      #default last action on load and save commands (reset or shutdown)
      :last_action: reset

Run proxies
-----------

To start/stop/restart the upstart service of nitos_testbed_rc use:

    % start ntrc 
    % stop ntrc
    % restart ntrc

Starting ntrc as an upstart will generate the following log files:

- user rc: /var/log/upstart/ntrc_user.log

- frisbee rc: /var/log/upstart/ntrc_frisbee.log

- cm rc: /var/log/upstart/ntrc_cm.log

Alternatively (mostly for debugging reasons) you can execute all proxies with one command:

    % run_proxies

Or you run proxies seperatly

    % user_proxy
    % cm_proxy
    % frisbee_proxy

Run omf6 commands
-----------------

Now you can use omf6 script to execute omf6 related commands

    % omf6 --help