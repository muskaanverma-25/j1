#!/bin/bash
# entry point for Docker container
echo "Ruby version is" $RUBY_VERSION
echo "ENV is" $ENV_NAME
echo "PORT is" $PORT
source /etc/profile.d/rvm.sh; rvm use $RUBY_VERSION

echo "Starting server in $ENV_NAME mode"
exec ruby script/server -e $ENV_NAME -p $PORT