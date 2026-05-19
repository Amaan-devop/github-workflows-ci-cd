#!/bin/bash

whoami
# rm -rf amazon-cloudwatch-agent.rpm
# wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
# rpm -U ./amazon-cloudwatch-agent.rpm
echo "Installed CloudWatchAgent"

cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "append_dimensions": {
    "AutoScalingGroupName": "\${aws:AutoScalingGroupName}",
    "InstanceId": "\${aws:InstanceId}"
  },
  "metrics": {
    "append_dimensions": {
      "AutoScalingGroupName": "\${aws:AutoScalingGroupName}",
      "InstanceId": "\${aws:InstanceId}"
    },
    "aggregation_dimensions": [
      [
        "AutoScalingGroupName",
        "InstanceId"
      ],
      [
        "AutoScalingGroupName"
      ]
    ],
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent",
          "mem_available",
          "mem_total"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ],
        "ignore_file_system_types": [
          "tmpfs",
          "devtmpfs"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/eb-engine.log",
            "log_group_name": "/aws/elasticbeanstalk/BEANSTALK_ENVIRONMET_NAME/var/log/eb-engine.log",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/eb-hooks.log",
            "log_group_name": "/aws/elasticbeanstalk/BEANSTALK_ENVIRONMET_NAME/var/log/eb-hooks.log",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/aws/elasticbeanstalk/BEANSTALK_ENVIRONMET_NAME/var/log/nginx/error.log",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/aws/elasticbeanstalk/BEANSTALK_ENVIRONMET_NAME/var/log/nginx/access.log",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/web.stdout.log",
            "log_group_name": "/aws/elasticbeanstalk/BEANSTALK_ENVIRONMET_NAME/var/log/web.stdout.log",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/amazon-cloudwatch-agent.json -s
echo "CloudWatchAgent is set"