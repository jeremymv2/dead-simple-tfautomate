resource "null_resource" "gen_ssh_key" {
  provisioner "local-exec" {
    command = "ls chef_id_rsa || ssh-keygen -t rsa -f chef_id_rsa -N ''"
  }
}

provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}" // uses ~/.aws/credentials by default
}

resource "aws_instance" "automate_cluster" {
  count = 3
  # count.index
  # 0 = Runner
  # 1 = Chef Server
  # 2 = Automate
  ami                         = "${data.aws_ami.centos.id}"
  instance_type               = "${element(var.aws_instance_types, count.index)}"
  key_name                    = "${var.aws_key_pair_name}"
  subnet_id                   = "${var.automate_subnet}"
  vpc_security_group_ids      = ["${var.automate_security_group}"]
  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true
    volume_size           = 20
    volume_type           = "gp2"
  }
  tags {
    X-Desc    = "${element(var.tag_names, count.index)}"
    X-Dept    = "${var.tag_dept}"
    X-Contact = "${var.tag_contact}"
  }
}

resource "null_resource" "provision_cluster" {
  count = 3

  connection {
    user        = "${var.aws_ami_user}"
    host        = "${element(aws_instance.automate_cluster.*.public_ip, count.index)}"
    private_key = "${file("${var.aws_key_pair_file}")}"
  }
  provisioner "file" {
    source = "chef_id_rsa"
    destination = "/var/tmp/id_rsa"
  }
  provisioner "file" {
    source = "chef_id_rsa.pub"
    destination = "/var/tmp/authorized_keys"
  }
  provisioner "file" {
    source = "delivery.license"
    destination = "/var/tmp/delivery.license"
  }
  provisioner "file" {
    source = "script.sh"
    destination = "/var/tmp/script.sh"
  }
  provisioner "file" {
    source = "variables.sh"
    destination = "/var/tmp/variables.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /var/tmp/script.sh",
      "sudo /var/tmp/script.sh ${count.index} ${element(aws_instance.automate_cluster.*.public_dns, 1)} ${element(aws_instance.automate_cluster.*.public_dns, 2)} ${element(aws_instance.automate_cluster.*.public_dns, 0)}"
    ]
  }
  provisioner "local-exec" {
    command = ". variables.sh && scp -oStrictHostKeyChecking=no -i chef_id_rsa -r $CHEF_SYS_USER@${element(aws_instance.automate_cluster.*.public_dns, 1)}:/home/$CHEF_SYS_USER/.chef . || true"
  }
}

output "chef_server" {
  value = "${aws_instance.automate_cluster.1.public_dns}"
}

output "automate" {
  value = "${aws_instance.automate_cluster.2.public_dns}"
}

output "runner" {
  value = "${aws_instance.automate_cluster.0.public_dns}"
}
