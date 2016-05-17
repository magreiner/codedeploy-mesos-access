#!/bin/bash

# start external haproxy
docker kill haproxy-external &>/dev/null
docker rm haproxy-external &>/dev/null
docker run --name haproxy-external \
           --privileged \
           -d \
           -e PORTS=1000 \
           --net=host mesosphere/marathon-lb sse \
           -m http://leader.mesos:8080 \
           --dont-bind-http-https \
           --group "ext"

# Enable logging
cat >> /tmp/docker_haproxy_logging.sh <<'EOF'
#!/bin/bash

apt-get update
apt-get --yes install hatop vim-tiny rsyslog nano
export TERM=vt100

echo "module(load=\"imudp\")" >> /etc/rsyslog.conf
echo "input(type=\"imudp\" port=\"514\")" >> /etc/rsyslog.conf
echo "local0.* /var/log/haproxy.local0" >> /etc/rsyslog.conf
echo "local1.* /var/log/haproxy.local1" >> /etc/rsyslog.conf

touch /var/log/haproxy.local0
touch /var/log/haproxy.local1
service rsyslog restart
EOF

# docker exec -it haproxy-external /bin/bash

# Access Container:
# docker exec -t -i haproxy-external /bin/bash

# Get some stats:
# hatop -s /var/run/haproxy/socket
