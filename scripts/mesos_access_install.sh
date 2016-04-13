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

#
# DOCKER
#
apt-get update
apt-get --yes install apt-transport-https ca-certificates

apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D

echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get --yes install apparmor \
                      linux-image-extra-$(uname -r)
apt-get --yes install docker-engine

usermod -aG docker ubuntu

service docker start



# start external haproxy
docker kill haproxy-external &>/dev/null
docker rm haproxy-external &>/dev/null
docker run --name haproxy-external --privileged -d -e PORTS=1000 --net=host mesosphere/marathon-lb sse -m http://$FIRST_MASTER_IP:8080 --group "ext" --dont-bind-http-https

# Access Container:
# docker exec -t -i haproxy-external /bin/bash

# Get some stats:
# apt-get update
# apt-get --yes install hatop vim-tiny
# export TERM=vt100
# hatop -s /var/run/haproxy/socket
