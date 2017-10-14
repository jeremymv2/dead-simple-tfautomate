current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                'delivery'
client_key               "#{current_dir}/user.pem"
ssl_verify_mode          :verify_none
chef_server_url          'https://ec2-35-162-75-156.us-west-2.compute.amazonaws.com/organizations/brewinc'
