# ffmpeg

This repository contains a Cloudformation yaml script for creating a Lambda function to trigger a Fargate task. The task will pull an mp4 video file and create a thumbnail from the video in an output bucket.

The design for the workflow is taken from this great article on serverless.com by Rupak Ganguly: https://serverless.com/blog/serverless-application-for-long-running-process-fargate-lambda/ (also for more details on the underlying ffmpeg utility see https://www.ffmpeg.org/documentation.html)

There are some modifications to the setup which include:
* The input bucket is not public - an IAM role is created and assigned to the ECS task to pull from this bucket
* The Lambda code has been ported to python3.6
* There is a slight change to the way the S3 input video file is passed to the task. The Lambda function passes the bucket and key details as separate parameters in the container overrides.
* The docker container has been rebuilt with very minor changes to enable the pull of the input video file from a non-public bucket. I have put this up on public dockerhub (see the 'containerid' parameter in the CF template)

## Install

1. Create a Cloudformation stack in the us-east-1 region (probably best to stick to this region until Fargate becomes more widely available) from ffmpeg.yml template
1. Update the Cloudformation stack created using template ffmpeg-update.yml. This is a workaround that adds a NotificationConfiguration for the S3 input bucket - issues with circular references mean it has to be done this way.
1. The Cloudformation outputs tab for the stack will show refs for bucketin and bucketout. Upload a video file to the bucketin location, the filename format must be [name]_[position nn-nn].mp4 (e.g. test_00-03.mp4)
1. Once the ECS task has completed the thumbnail will be available in bucketout
1. Logs for both the ECS task and the Lambda function can be viewed in Cloudwatch Logs


## Docker image build

Optionally you may want to build your own Docker image - example below of how to do this (from a Centos 7 box):

* create the retrieve_file.sh script
```
# create the retrieve_file.sh script
cat << 'EOF' > retrieve_file.sh
#!/bin/bash

echo "Copying ${INPUT_VIDEO_FILE_KEY} from S3 bucket ${INPUT_VIDEO_FILE_BUCKET}..."
aws s3api get-object --bucket ${INPUT_VIDEO_FILE_BUCKET} --key ${INPUT_VIDEO_FILE_KEY} ${INPUT_VIDEO_FILE_KEY}

EOF
```
* Create the retrieve_file.sh script
```
cat << 'EOF' > retrieve_file.sh
#!/bin/bash

echo "Copying ${INPUT_VIDEO_FILE_KEY} from S3 bucket ${INPUT_VIDEO_FILE_BUCKET}..."
aws s3api get-object --bucket ${INPUT_VIDEO_FILE_BUCKET} --key ${INPUT_VIDEO_FILE_KEY} ${INPUT_VIDEO_FILE_KEY}

EOF
```

* Create the Dockerfile
```
cat << 'EOF' > Dockerfile
FROM jrottenberg/ffmpeg
LABEL maintainer="Darren Reddick <dreddick.home@gmail.com>"

RUN apt-get update && \
    apt-get install python-dev python-pip -y && \
    apt-get clean

RUN pip install awscli

WORKDIR /tmp/workdir

COPY copy_thumbs.sh /tmp/workdir
COPY retrieve_file.sh /tmp/workdir

RUN chmod u+x copy_thumbs.sh
RUN chmod u+x retrieve_file.sh

ENTRYPOINT ./retrieve_file.sh && \
ffmpeg -i ${INPUT_VIDEO_FILE_KEY} \
-ss ${POSITION_TIME_DURATION} -vframes 1 -vcodec png \
-an -y ${OUTPUT_THUMBS_FILE_NAME} && ./copy_thumbs.sh

EOF
```

* Build the docker image
```
docker build -f Dockerfile -t akumadare/docker-ffmpeg-thumb .
```





