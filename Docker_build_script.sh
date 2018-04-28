#!/bin/bash

# create the copy_thumbs.sh script
cat << 'EOF' > copy_thumbs.sh
#!/bin/bash

echo "Copying ${OUTPUT_THUMBS_FILE_NAME} to S3 at ${OUTPUT_S3_PATH}/${OUTPUT_THUMBS_FILE_NAME} ..."
aws s3 cp ./${OUTPUT_THUMBS_FILE_NAME} s3://${OUTPUT_S3_PATH}/${OUTPUT_THUMBS_FILE_NAME} --region ${AWS_REGION}

EOF

# create the retrieve_file.sh script
cat << 'EOF' > retrieve_file.sh
#!/bin/bash

echo "Copying ${INPUT_VIDEO_FILE_KEY} from S3 bucket ${INPUT_VIDEO_FILE_BUCKET}..."
aws s3api get-object --bucket ${INPUT_VIDEO_FILE_BUCKET} --key ${INPUT_VIDEO_FILE_KEY} ${INPUT_VIDEO_FILE_KEY}

EOF

# create the Dockerfile
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

# build the docker image
docker build -f Dockerfile -t akumadare/docker-ffmpeg-thumb .