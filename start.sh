#!/bin/bash

# Disable Strict Host checking for non interactive git clones

mkdir -p -m 0700 /root/.ssh
echo -e "Host *\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config

# Setup git variables
if [ ! -z "$GIT_EMAIL" ]; then
 git config --global user.email "$GIT_EMAIL"
fi
if [ ! -z "$GIT_NAME" ]; then
 git config --global user.name "$GIT_NAME"
 git config --global push.default simple
fi

# Pull down code form git for our site!
if [ ! -z "$GIT_REPO" ]; then
  rm -rf /data/webroot/*
  if [ ! -z "$GIT_BRANCH" ]; then
    git clone -b $GIT_BRANCH $GIT_REPO /data/webroot/
  else
    git clone $GIT_REPO /data/webroot/
  fi
  chown -Rf nginx.nginx /usr/share/nginx/*
fi

# Tweak nginx to match the workers to cpu's

procs=$(cat /proc/cpuinfo |grep processor | wc -l)
sed -i -e "s/worker_processes 5/worker_processes $procs/" /etc/nginx/nginx.conf

# Very dirty hack to replace variables in code with ENVIRONMENT values
# if [[ "$TEMPLATE_NGINX_HTML" != "0" ]] ; then
#   for i in $(env)
#   do
#     variable=$(echo "$i" | cut -d'=' -f1)
#     value=$(echo "$i" | cut -d'=' -f2)
#     if [[ "$variable" != '%s' ]] ; then
#       replace='\$\$_'${variable}'_\$\$'
#       find /data/webroot -type f -exec sed -i -e 's/'${replace}'/'${value}'/g' {} \;
#     fi
#   done
# fi

# Start supervisord and services
/usr/bin/supervisord -n -c /etc/supervisord.conf &

if [ "${AUTHORIZED_KEYS}" != "**None**" ]; then
    echo "=> Found authorized keys"
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    touch /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    IFS=$'\n'
    arr=$(echo ${AUTHORIZED_KEYS} | tr "," "\n")
    for x in $arr
    do
        x=$(echo $x |sed -e 's/^ *//' -e 's/ *$//')
        cat /root/.ssh/authorized_keys | grep "$x" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "=> Adding public key to /root/.ssh/authorized_keys: $x"
            echo "$x" >> /root/.ssh/authorized_keys
        fi
    done
fi

if [ ! -f /.root_pw_set ]; then
        /set_root_pw.sh
fi

exec /usr/sbin/sshd -D
