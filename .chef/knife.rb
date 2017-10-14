current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                'delivery'
client_key               "#{current_dir}/delivery.pem"
ssl_verify_mode          :verify_none
chef_server_url          'https://ec2-52-32-130-210.us-west-2.compute.amazonaws.com/organizations/brewinc'
