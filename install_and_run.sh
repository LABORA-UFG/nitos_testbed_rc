#!/usr/bin/env bash
DOMAIN=ufg.br
AM_SERVER_DOMAIN=ufg.br
XMPP_DOMAIN=ufg.br

echo $(pwd)

cd /media/arquivos/idea-projects/nitos_testbed_rc/

mkdir -p ~/.omf/trusted_roots
omf_cert.rb --email root@$DOMAIN -o ~/.omf/trusted_roots/root.pem --duration 50000000 create_root
omf_cert.rb -o ~/.omf/am.pem  --geni_uri URI:urn:publicid:IDN+$AM_SERVER_DOMAIN+user+am --email am@$DOMAIN --resource-id xmpp://am_controller@$XMPP_DOMAIN --resource-type am_controller --root ~/.omf/trusted_roots/root.pem --duration 50000000 create_resource
omf_cert.rb -o ~/.omf/user_cert.pem --geni_uri URI:urn:publicid:IDN+$AM_SERVER_DOMAIN+user+root --email root@$DOMAIN --user root --root ~/.omf/trusted_roots/root.pem --duration 50000000 create_user

openssl rsa -in ~/.omf/am.pem -outform PEM -out ~/.omf/am.pkey
openssl rsa -in ~/.omf/user_cert.pem -outform PEM -out ~/.omf/user_cert.pkey

gem build nitos_testbed_rc.gemspec
sudo gem install nitos_testbed_rc-2.0.5.gem

sudo install_ntrc

##START OF CERTIFICATES CONFIGURATION
omf_cert.rb -o ~/.omf/user_factory.pem --email user_factory@$DOMAIN --resource-type user_factory --resource-id xmpp://user_factory@$XMPP_DOMAIN --root ~/.omf/trusted_roots/root.pem --duration 50000000 create_resource
omf_cert.rb -o ~/.omf/cm_factory.pem --email cm_factory@$DOMAIN --resource-type cm_factory --resource-id xmpp://cm_factory@$XMPP_DOMAIN --root ~/.omf/trusted_roots/root.pem --duration 50000000 create_resource
omf_cert.rb -o ~/.omf/frisbee_factory.pem --email frisbee_factory@$DOMAIN --resource-type frisbee_factory --resource-id xmpp://frisbee_factory@$XMPP_DOMAIN --root ~/.omf/trusted_roots/root.pem --duration 50000000 create_resource
sudo cp -r ~/.omf/trusted_roots/ /etc/nitos_testbed_rc/
