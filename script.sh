#!/bin/bash

export PATH=/opt/opscode/embedded/bin:/usr/sbin:$PATH
export CHEFSERVER=$2
export AUTOMATESERVER=$3
export RUNNER=$4

. $(dirname "$0")/variables.sh

random_string () {
  cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
}

setup_chef_user () {
 if [ ! -f /home/$CHEF_SYS_USER ]; then
   useradd $CHEF_SYS_USER -m
   mv /var/tmp/delivery.license /home/$CHEF_SYS_USER
   mkdir /home/$CHEF_SYS_USER/.ssh
   mv /var/tmp/authorized_keys /home/$CHEF_SYS_USER/.ssh
   mv /var/tmp/id_rsa /home/$CHEF_SYS_USER/.ssh
   chown -R $CHEF_SYS_USER:$CHEF_SYS_USER /home/$CHEF_SYS_USER/.ssh
   chmod 700 /home/$CHEF_SYS_USER/.ssh
   chmod 600 /home/$CHEF_SYS_USER/.ssh/authorized_keys
   chmod 600 /home/$CHEF_SYS_USER/.ssh/id_rsa
   mkdir /home/$CHEF_SYS_USER/.chef
 fi
}

install_chef_server () {
  rpm -Uvh `curl -s https://downloads.chef.io/chef-server/stable | grep -o '</strong> https:[^<]*[^<]*el7.x86_64.rpm' | grep -o 'https.*' | sed -e 's/\&\#x2F;/\\//g' | head -1`

  kniferb="/home/$CHEF_SYS_USER/.chef/knife.rb"
  echo "current_dir = File.dirname(__FILE__)" | tee -a $kniferb
  echo "log_level                :info" | tee -a $kniferb
  echo "log_location             STDOUT" | tee -a $kniferb
  echo "node_name                '$CHEF_WF_USER'" | tee -a $kniferb
  echo "client_key               \"#{current_dir}/$CHEF_WF_USER.pem\"" | tee -a $kniferb
  echo "ssl_verify_mode          :verify_none" | tee -a $kniferb
  echo "chef_server_url          'https://$CHEFSERVER/organizations/$CHEF_ORG'" | tee -a $kniferb

  serverrb="/etc/opscode/chef-server.rb"
  echo "api_fqdn \"$CHEFSERVER\"" |  tee -a $serverrb
  echo "data_collector['root_url'] = 'https://$AUTOMATESERVER/data-collector/v0/'" | tee -a $serverrb
  echo "data_collector['token'] = '93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506'" | tee -a $serverrb
  echo "profiles['root_url'] = 'https://$AUTOMATESERVER'" | tee -a $serverrb

  chef-server-ctl reconfigure
  chef-server-ctl user-create admin the admin admin@the.admin.io $(random_string) --filename /home/$CHEF_SYS_USER/admin.pem
  chef-server-ctl org-create $CHEF_ORG "$CHEF_ORG" --association_user admin --filename /home/$CHEF_SYS_USER/$CHEF_ORG-validator.pem
  chef-server-ctl user-create $CHEF_WF_USER $CHEF_WF_USER User $CHEF_WF_USER@example.com $(random_string) --filename /home/$CHEF_SYS_USER/.chef/$CHEF_WF_USER.pem
  chef-server-ctl org-user-add $CHEF_ORG $CHEF_WF_USER --admin
}

get_chef_wf_user_pem () {
  scp -oStrictHostKeyChecking=no -i /home/$CHEF_SYS_USER/.ssh/id_rsa $CHEF_SYS_USER@$1:/home/$CHEF_SYS_USER/.chef/$CHEF_WF_USER.pem /etc/delivery/$CHEF_WF_USER.pem >/dev/null 2>&1
}

install_automate_server () {
  rpm -Uvh `curl -s https://downloads.chef.io/automate/stable | grep -o '</strong> https:[^<]*[^<]*el7.x86_64.rpm' | grep -o 'https.*' | sed -e 's/\&\#x2F;/\\//g' | head -1`

  mkdir -p /var/opt/delivery/license
  mv /home/$CHEF_SYS_USER/delivery.license /var/opt/delivery/license
  mkdir -p /etc/delivery
  chmod 0644 /etc/delivery
  get_chef_wf_user_pem $CHEFSERVER
  while [ $? -ne 0 ]; do
    echo "Automate Server: interrogtating the Chef Server for a $CHEF_WF_USER.pem.."
    sleep 10
    get_chef_wf_user_pem $CHEFSERVER
  done
  automate-ctl setup --license /var/opt/delivery/license/delivery.license --enterprise $WF_ENT --no-build-node --key /etc/delivery/$CHEF_WF_USER.pem --server-url https://$CHEFSERVER/organizations/$CHEF_ORG --fqdn $AUTOMATESERVER --no-configure
  automate-ctl reconfigure
  sleep 15
  pass=$(random_string)
  automate-ctl create-enterprise $WF_ENT --ssh-pub-key-file /etc/delivery/builder_key.pub
  automate-ctl install-runner $RUNNER $CHEF_SYS_USER --ssh-identity-file /home/$CHEF_SYS_USER/.ssh/id_rsa -y
  automate-ctl reset-password $WF_ENT admin $pass
  echo "NEW LOGIN (/etc/delivery/ui_login.info): admin / $pass" > /etc/delivery/ui_login.info
  chmod 600 /etc/delivery/ui_login.info
  cat /etc/delivery/ui_login.info
}

install_runner () {
  echo "Installing Runner.."
  echo "$CHEF_SYS_USER ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers.d/90-cloud-init-users
}

setup_chef_user

if [ $1 -eq 0 ]; then
  install_runner
elif [ $1 -eq 1 ]; then
  install_chef_server
else
  install_automate_server
fi
