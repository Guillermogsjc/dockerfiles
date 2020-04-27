#! /bin/sh

set -e
set -o pipefail

if [ "${S3_LS_PAGE_SIZE}" = "**None**" ]; then
  echo "Setting default AWS S3 LS page size"
  export S3_LS_PAGE_SIZE=3000
else
  export S3_LS_PAGE_SIZE=$S3_LS_PAGE_SIZE
fi

if [ "${S3_REGION}" = "**None**" ]; then
  echo "Going for IAM Role def for AWS region"
else
  export AWS_DEFAULT_REGION=$S3_REGION
fi

if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "Going for IAM Role def for AWS ACCESS_KEY_ID"
else
  export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "Going for IAM Role def for AWS SECRET_ACCESS_KEY"
else
  export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${POSTGRES_DATABASE}" = "**None**" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi


export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER"

echo "Finding latest backup"

LATEST_BACKUP=$(aws s3 ls --page-size $S3_LS_PAGE_SIZE s3://$S3_BUCKET/$S3_PREFIX/ | sort | tail -n 1 | awk '{ print $4 }')

echo "Fetching ${LATEST_BACKUP} from S3"

aws s3 cp s3://$S3_BUCKET/$S3_PREFIX/${LATEST_BACKUP} dump.sql.gz
gzip -d dump.sql.gz

if [ "${DROP_PUBLIC}" == "yes" ]; then
	echo "Recreating the public schema"
	psql $POSTGRES_HOST_OPTS -d $POSTGRES_DATABASE -c "drop schema public cascade; create schema public;"
fi

echo "Restoring ${LATEST_BACKUP}"

psql $POSTGRES_HOST_OPTS -d $POSTGRES_DATABASE < dump.sql

echo "Restore complete"

