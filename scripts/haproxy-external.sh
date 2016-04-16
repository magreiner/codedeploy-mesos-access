#!/bin/bash

MIN_MASTER_INSTANCES=1
MASTER_INSTANCE_TAGNAME="AS_Master"

AZ="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
REGION="${AZ::-1}"

# Looking for other master instances for HA (Zookeeper)
MASTER_IPS=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=$MASTER_INSTANCE_TAGNAME" | jq '. | {ips: .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress}' | grep "\." | cut -f4 -d'"')
MASTER_INSTANCES_ONLINE=$(echo "$MASTER_IPS" | grep "\." | wc -l)

while [ "$MASTER_INSTANCES_ONLINE" -lt "$MIN_MASTER_INSTANCES" ]; do
  sleep 2
  echo "Waiting for more master instances. ($MASTER_INSTANCES_ONLINE/$MIN_MASTER_INSTANCES online)"
  MASTER_IPS=$(aws ec2 describe-instances --region $REGION --filters "Name=tag:Name,Values=$MASTER_INSTANCE_TAGNAME" | jq '. | {ips: .Reservations[].Instances[].NetworkInterfaces[].PrivateIpAddress}' | grep "\." | cut -f4 -d'"' | head -n1)
  MASTER_INSTANCES_ONLINE=$(echo "$MASTER_IPS" | grep "\." | wc -l)
done
FIRST_MASTER_IP=$(echo "$MASTER_IPS" | head -n1)

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
