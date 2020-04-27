#! /bin/sh

set -e

if [ "${INITIAL_WAIT}" = "**None**" ]; then
  echo "Waiting a bit before starting synchro cron"
  export INITIAL_WAIT=60
else
  export INITIAL_WAIT=$INITIAL_WAIT
fi

echo "Waiting a bit"
sleep $INITIAL_WAIT

if [ "${S3_S3V4}" = "yes" ]; then
    aws configure set default.s3.signature_version s3v4
fi

if [ "${SCHEDULE}" = "**None**" ]; then
  sh backup.sh
else
  exec go-cron "$SCHEDULE" /bin/sh backup.sh
fi
