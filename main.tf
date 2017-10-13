provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}" // uses ~/.aws/credentials by default
}

resource "aws_instance" "automate_cluster" {
  count = 2
  ami                         = "${data.aws_ami.centos.id}"
  instance_type               = "${var.aws_instance_type}"
  key_name                    = "${var.aws_key_pair_name}"
  subnet_id                   = "${var.automate_subnet}"
  vpc_security_group_ids      = ["${var.automate_security_group}"]
  associate_public_ip_address = true
  ebs_optimized               = true

  root_block_device {
    delete_on_termination = true
    volume_size           = 20
    volume_type           = "gp2"
  }
  tags {
    X-Dept    = "${var.tag_dept}"
    X-Contact = "${var.tag_contact}"
  }
}

resource "null_resource" "provision_cluster" {
  count = 2

  connection {
    user        = "${var.aws_ami_user}"
    host        = "${element(aws_instance.automate_cluster.*.public_ip, count.index)}"
    private_key = "${file("${var.aws_key_pair_file}")}"
  }
  provisioner "file" {
    source = "delivery.license"
    destination = "/var/tmp/delivery.license"
  }
  provisioner "file" {
    source = "script.sh"
    destination = "/var/tmp/script.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "chmod +x /var/tmp/script.sh",
      "sudo /var/tmp/script.sh ${count.index} ${join(" ", aws_instance.automate_cluster.*.public_dns)}"
    ]
  }
  provisioner "local-exec" {
    command = "curl -s -k http://${element(aws_instance.automate_cluster.*.public_dns, count.index)}:8890/knife.rb -o .chef/knife.rb -m 3 || true"
  }
  provisioner "local-exec" {
    command = "curl -s -k http://${element(aws_instance.automate_cluster.*.public_dns, count.index)}:8890/delivery.pem -o .chef/delivery.pem -m 3 || true"
  }
}
