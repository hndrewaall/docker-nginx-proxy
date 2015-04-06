FROM nginx:1.7.11
MAINTAINER https://m-ko-x.de Markus Kosmal <code@m-ko-x.de>

# Choose the template to run, you may use dev for experimental use
ENV GLOB_TMPL_MODE run

# Set max size within a body
ENV GLOB_MAX_BODY_SIZE 10m

# Enable bundle support to provide nginx CA chain.
# Have a look at http://nginx.org/en/docs/http/configuring_https_servers.html#chains for more info.
ENV GLOB_SSL_CERT_BUNDLE_INFIX ""

# Set default session timeout
ENV GLOB_SSL_SESSION_TIMEOUT 5m

# Set default shared session cache
ENV GLOB_SSL_SESSION_CACHE 50m

# Sctivate SPDY support
# More info https://www.mare-system.de/guide-to-nginx-ssl-spdy-hsts/
ENV GLOB_SPDY_ENABLED "0"

# Default return code for errors
ENV GLOB_HTTP_NO_SERVICE 503

# Redirect prefixed to non prefix  (e.g. 'http://WWW.xyz.io' to 'http://xyz.io')
ENV GLOB_AUTO_REDIRECT_ENABLED "0"

# Set prefix to be used for auto redirect
ENV GLOB_AUTO_REDIRECT_PREFIX www

# set direction
# - 0: redirect from prefix to non-prefix (e.g. 'http://WWW.xyz.io' to 'http://xyz.io')
# - 1: redirect from non-prefix to prefix (e.g. 'http://xyz.io' to 'http://API.xyz.io')
ENV GLOB_AUTO_REDIRECT_DIRECTION "0"

# Only allow ssl
ENV GLOB_HTTPS_FORCE "1"

# Allow to use http only if https is not available
ENV GLOB_ALLOW_HTTP_FALLBACK "0"

# User to run the proxy
ENV GLOB_USER_NAME nginx

# Multilevel proxy cache
ENV GLOB_CACHE_ENABLE "1"

# Define the amount of workers nginx should use
ENV GLOB_WORKER_COUNT auto

# Limit the maximum amount of total connections
ENV GLOB_WORKER_CONNECTIONS 256

# Allow each worker to process multiple connections at once
ENV GLOB_WORKER_MULTI_ACCEPT on

# Set the maximum open file handles of each worker
ENV GLOB_WORKER_RLIMIT_NOFILE 1024

# Set the default error log level
ENV GLOB_ERROR_LOG_LEVEL error

# Time the server keeps the connection active without request from client
ENV GLOB_KEEPALIVE_TIMEOUT 60

# Connect to docker host via socket by default
ENV DOCKER_HOST unix:///tmp/docker.sock

# Set docker gen version to use
ENV DOCKER_GEN_VERSION 0.3.9

# Install packages
RUN apt-get update -y -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    ca-certificates \
    wget \
    cron \
 && apt-get clean -y -qq \
 && rm -r /var/lib/apt/lists/*
 
# Install Forego
RUN wget -P /usr/local/bin -q https://godist.herokuapp.com/projects/ddollar/forego/releases/current/linux-amd64/forego \
 && chmod u+x /usr/local/bin/forego

# Install Docker-Gen
RUN wget -q https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && tar -C /usr/local/bin -xvzf docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz \
 && rm /docker-gen-linux-amd64-$DOCKER_GEN_VERSION.tar.gz

# Add PID file for the process
ADD ./conf/Procfile /app/

# Put clean nginx conf
RUN rm -f /etc/nginx/*
ADD ./conf/nginx.conf /etc/nginx/

# Update nginx conf
ADD ./conf/prepare.sh /up/prepare.sh
RUN chmod a+x /up/prepare.sh && cd /up && ./prepare.sh && rm -rf /up

# Schedule log rotation
ADD ./conf/rotate_nginx_log.sh /usr/local/sbin/rotate_nginx_log.sh
RUN chmod +x /usr/local/sbin/rotate_nginx_log.sh
RUN mkdir -p /etc/cron.d
RUN echo "* 1 * * * /usr/local/sbin/rotate_nginx_log.sh" >> /etc/cron.d/nginx_log

# Change to working directory
WORKDIR /app/

# Add late, as tmpl is most modified part and less content needs to be rebuilt
ADD ./conf/nginx-${GLOB_TMPL_MODE}.tmpl ./nginx.tmpl

VOLUME ["/etc/nginx/certs","/etc/nginx/htpasswd","/etc/nginx/vhost.d/","/etc/nginx/conf.d/"]
CMD ["forego", "start", "-r"]
