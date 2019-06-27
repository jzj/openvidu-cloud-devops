#!/bin/bash

# This script will launch OpenVidu Server on your machine

{% if whichcert == "letsencrypt" or whichcert == "owncert" %}
PUBLIC_HOSTNAME={{ domain_name }}
{% else %}
{% if run_ec2 == true %}
PUBLIC_HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/public-hostname)
{% else %}
PUBLIC_HOSTNAME={{ ov_public_hostname }}
{% endif %}
{% endif %}

# Wait for kibana
while true
do 
  HTTP_STATUS=$(curl -I http://localhost:5601/app/kibana | head -n1 | awk '{print $2}')
  if [ $HTTP_STATUS == 200 ]; then
    break
  fi
  sleep 1
done

OPENVIDU_OPTIONS="-Dopenvidu.secret={{ openvidusecret }} "
OPENVIDU_OPTIONS+="-Dopenvidu.recording=true "
OPENVIDU_OPTIONS+="-Dopenvidu.recording.public-access={{ FreeHTTPAccesToRecordingVideos }} "
OPENVIDU_OPTIONS+="-Dserver.ssl.enabled=false "
OPENVIDU_OPTIONS+="-Dopenvidu.publicurl=https://${PUBLIC_HOSTNAME}:{{ openvidu_port }} "
OPENVIDU_OPTIONS+="-Dserver.port=5443 "
OPENVIDU_OPTIONS+="-DMY_UID=$(id -u $USER) "
OPENVIDU_OPTIONS+="-Dopenvidu.recording.notification={{ OpenviduRecordingNotification }} "
OPENVIDU_OPTIONS+="-Dopenvidu.streams.video.max-recv-bandwidth={{ OpenviduStreamsVideoMaxRecvBandwidth }} "
OPENVIDU_OPTIONS+="-Dopenvidu.streams.video.min-recv-bandwidth={{ OpenviduStreamsVideoMinRecvBandwidth }} "
OPENVIDU_OPTIONS+="-Dopenvidu.streams.video.max-send-bandwidth={{ OpenviduStreamsVideoMaxSendBandwidth }} "
OPENVIDU_OPTIONS+="-Dopenvidu.streams.video.min-send-bandwidth={{ OpenviduStreamsVideoMinSendBandwidth }} "
OPENVIDU_OPTIONS+="-Dopenvidu.pro.kibana.host=http://localhost/kibana "
OPENVIDU_OPTIONS+="-Dopenvidu.recording.composed-url=https://${PUBLIC_HOSTNAME}/inspector/ "
OPENVIDU_OPTIONS+="-Dopenvidu.pro.cluster=true "
OPENVIDU_OPTIONS+="-Dopenvidu.pro.cluster.load.strategy={{ OpenviduClusterLoadStrategy }} "
OPENVIDU_OPTIONS+="-Dopenvidu.webhook={{ webhook_enabled }} "
OPENVIDU_OPTIONS+="-Dopenvidu.webhook.endpoint={{ webhook_endpoint }} "

HEADERS=$(echo {{ webhook_headers }} | sed -e 's/[^a-zA-Z0-9,._+@%/-]/\\&/g; 1{$s/^$/""/}; 1!s/^/"/; $!s/$/"/')
OPENVIDU_OPTIONS+="-Dopenvidu.webhook.headers=[\"${HEADERS}\"] "

EVENTS_LIST=$(echo {{ webhook_events }} | tr , ' ')
E=$(for EVENT in ${EVENTS_LIST}
do
	echo $EVENT | awk '{ print "\"" $1 "\"" }'
done
)
EVENTS=$(echo $E | tr ' ' ,)
OPENVIDU_OPTIONS+="-Dopenvidu.webhook.events=[${EVENTS}] "

{% if run_ec2 == true %}
export AWS_DEFAULT_REGION={{ aws_default_region }}
KMS_IPs=$(aws ec2 describe-instances --query 'Reservations[].Instances[].[PrivateIpAddress]' --output text --filters Name=instance-state-name,Values=running Name=tag:ov-cluster-member,Values=kms)
{% else %}
KMS_IPs=$(echo {{ kms_endpoint_ips }} | tr , ' ')
{% endif %}
KMS_ENDPOINTS=$(for IP in $KMS_IPs
do
  echo $IP | awk '{ print "\"ws://" $1 ":8888/kurento\"" }'
done
)
KMS_ENDPOINTS_LINE=$(echo $KMS_ENDPOINTS | tr ' ' ,)
OPENVIDU_OPTIONS+="-Dkms.uris=[${KMS_ENDPOINTS_LINE}] "

pushd /opt/openvidu
exec java -jar ${OPENVIDU_OPTIONS} /opt/openvidu/openvidu-server.jar

