#!/bin/bash

MASTER_INSTANCE_TAGNAME="AS_Master"

LOCAL_IP_ADDRESS="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
AZ="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
REGION="${AZ::-1}"

MASTER_IPS="$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=$MASTER_INSTANCE_TAGNAME" --query 'Reservations[*].Instances[*].NetworkInterfaces[*].PrivateIpAddress' --output text)"
FIRST_MASTER_IP="$(echo "$MASTER_IPS" | head -n1)"

# start external haproxy
docker kill haproxy-external &>/dev/null
docker rm haproxy-external &>/dev/null
docker run --name haproxy-external \
           --privileged \
           -d \
           -e PORTS=1000 \
           --net=host mesosphere/marathon-lb sse \
           -m http://$FIRST_MASTER_IP:8080 \
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
