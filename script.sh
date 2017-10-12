#!/bin/bash

export PATH=/opt/opscode/embedded/bin:$PATH

install_chef_server () {
  echo "Installing Chef Server. Parameters: $1 $2" > /root/install.log
  read CHEFSERVER AUTOMATESERVER < <(who_is_what $1 $2)
  export CHEFSERVER_RPM=`curl -s https://downloads.chef.io/chef-server/stable | grep -o '</strong> https:[^<]*[^<]*el7.x86_64.rpm' | grep -o 'https.*' | sed -e 's/\&\#x2F;/\\//g' | head -1`

  rm -f /var/tmp/delivery.license

  rpm -Uvh $CHEFSERVER_RPM
  mkdir /root/share

  echo "api_fqdn \"$CHEFSERVER\"" |  tee --append /etc/opscode/chef-server.rb >/dev/null
  echo "data_collector['root_url'] = 'https://$AUTOMATESERVER/data-collector/v0/'" | tee --append /etc/opscode/chef-server.rb >/dev/null
  echo "data_collector['token'] = '93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506'" | tee --append /etc/opscode/chef-server.rb >/dev/null
  echo "profiles['root_url'] = 'https://$AUTOMATESERVER'" | tee --append /etc/opscode/chef-server.rb >/dev/null

  chef-server-ctl reconfigure
  chef-server-ctl user-create admin the admin admin@the.admin.io $RANDOM$RANDOM --filename /root/admin.pem
  chef-server-ctl org-create brewinc "Brew, Inc." --association_user admin --filename /root/brewinc-validator.pem
  chef-server-ctl user-create delivery Delivery User delivery@example.com $RANDOM$RANDOM --filename /root/share/delivery.pem
  chef-server-ctl org-user-add brewinc delivery --admin

  echo "running web server to serve up /root/share"
  cd /root/share
  nohup ruby -run -e httpd . -p 8989 --bind-address 0.0.0.0 &
  yum install -y lsof
  export rails_pid=`lsof -i :8989 | awk '{print $2}' | grep -v PID`
  yum install -y at
  systemctl start atd
  echo "sleep 600 ; kill -9 $rails_pid" | at now

  chef-server-ctl install chef-manage
  chef-server-ctl reconfigure

  sleep 10

  chef-manage-ctl reconfigure --accept-license
}

get_delivery_pem () {
  curl -k -s http://$1:8989/delivery.pem -o /etc/delivery/delivery.pem
}

who_is_what () {
  export me=`curl -s http://169.254.169.254/latest/meta-data/public-hostname`
  if [ $1 == $me ]; then
    echo $1 $2
  else
    echo $2 $1
  fi
 }

install_automate_server () {
  echo "Installing Chef Server. Parameters: $1 $2" > /root/install.log
  read AUTOMATESERVER CHEFSERVER < <(who_is_what $1 $2)
  export AUTOMATESERVER_RPM=`curl -s https://downloads.chef.io/automate/stable | grep -o '</strong> https:[^<]*[^<]*el7.x86_64.rpm' | grep -o 'https.*' | sed -e 's/\&\#x2F;/\\//g' | head -1`

  rpm -Uvh $AUTOMATESERVER_RPM

  mkdir /root/share
  mkdir -p /var/opt/delivery/license
  cp -f /var/tmp/delivery.license /var/opt/delivery/license
  mkdir -p /etc/delivery
  chmod 0644 /etc/delivery
  get_delivery_pem $CHEFSERVER
  while [ $? -ne 0 ]; do
    echo "Automate Server: I'm checking for delivery.pem on remote Chef Server $CHEFSERVER..."
    sleep 10
    get_delivery_pem $CHEFSERVER
  done
  automate-ctl setup --license /var/opt/delivery/license/delivery.license --enterprise brewinc --no-build-node --key /etc/delivery/delivery.pem --server-url https://$CHEFSERVER/organizations/brewinc --fqdn $AUTOMATESERVER --no-configure
  automate-ctl reconfigure
  sleep 15
  pass=$RANDOM$RANDOM
  automate-ctl create-enterprise brewinc --ssh-pub-key-file /etc/delivery/builder_key.pub
  automate-ctl reset-password brewinc admin $pass
  echo "admin / $pass" > /etc/delivery/ui_login.info
  chmod 600 /etc/delivery/ui_login.info
  echo "New Login Info:"
  cat /etc/delivery/ui_login.info
}


if [ $# -le 0 ]; then
  echo "Illegal number of parameters"
elif [ $1 -eq 1 ]; then
  install_chef_server $2 $3
else
  install_automate_server $2 $3
fi
