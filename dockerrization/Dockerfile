FROM ubuntu:14.04

ENV OMF_SFA_HOME=/root/omf_sfa
ENV INVENTORY_PATH=/root/omf_sfa/inventory.rb
ENV DOMAIN=ufg.br
ENV AM_SERVER_DOMAIN=ufg.br
ENV XMPP_DOMAIN=ufg.br

#RUN echo 'deb http://pkg.mytestbed.net/ubuntu precise/ ' >> /etc/apt/sources.list \
RUN apt-get update
RUN apt-get install -y --force-yes \
   build-essential \
   dnsmasq \
   git \
   libsqlite3-dev \
   libreadline6-dev \
   libssl-dev \
   libyaml-dev \
   libxml2-dev \
   libxmlsec1-dev \
   libxslt-dev \
   nano \
   ntp \
   syslinux \
   xmlsec1 \
   wget \
   zlib1g-dev

RUN cd /tmp \
   && wget http://ftp.ruby-lang.org/pub/ruby/2.2/ruby-2.2.3.tar.gz \
   && tar -xvzf ruby-2.2.3.tar.gz \
   && cd ruby-2.2.3/ \
   && ./configure --prefix=/usr/local \
   && make \
   && make install \
   && rm -rf /tmp/ruby

RUN gem install bundler --no-ri --no-rdoc

#EXPOSE 8001/tcp

#BEGIN COPY CONFIGURATION FILE
COPY testbed-files /root/testbed-files/
#END COPY CONFIGURATION FILE

#PULL FROM GIT HUB AND RUN BROKER
COPY entrypoint.sh /usr/bin/
RUN chmod 755 /usr/bin/entrypoint.sh
ENTRYPOINT ["/usr/bin/entrypoint.sh"]