
provider "aws" {
  #access_key = "${var.access_key}"
  #secret_key = "${var.secret_key}"
  #region = "${var.aws_region}"
}

resource "aws_instance" "web" {
  count = "${var.instance_count}"
  instance_type = "t2.small" 
  ami = "ami-0ac05733838eabc06"
  vpc_security_group_ids = ["sg-09856843f6db67618"]
  key_name = "frankfurtkeypair"

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "${var.ssh_user_name}"
      private_key = "${file("${var.ssh_key_path}")}"
      #password = "${var.root_password}"
      host     = "${self.private_ip}"
    }
    inline    = ["sudo sh -c 'echo ''172.31.6.99 chefserver'' >> /etc/hosts'"]
    }

  provisioner "chef" {
    connection {
      type     = "ssh"
      user     = "ubuntu"
      private_key = "${file("/root/.ssh/id_rsa")}"
      #password = "${var.root_password}"
      host     = "${self.private_ip}"
    }
    attributes_json = <<EOF
      {
        "key": "value",
        "app": {
          "cluster1": {
            "nodes": [
              "webserver1",
              "webserver2"
            ]
          }
        }
      }
    EOF
    vault_json = <<-EOF
    {
      "vaultbag": [
        "gitkey"
      ]
    }
    EOF

    #environment     = "production"
    use_policyfile = true
    policy_group = "production"
    policy_name = "django-tutorial"
    #log_to_file = true
    client_options  = ["chef_license 'accept'"]
    run_list        = ["cookbook::recipe"]
    node_name       = "web${count.index}"
    #secret_key      = "${file("../encrypted_data_bag_secret")}"
    #server_url      = "https://chef.company.com/organizations/org1"
    server_url      = "https://chefserver/organizations/testorg"
    recreate_client = true
    user_name       = "sdarwin"
    user_key        = "${file("/root/.chef/sdarwin.pem")}"
    #version         = "12.4.1"
    # If you have a self signed cert on your chef server change this to :verify_none
    #ssl_verify_mode = ":verify_peer"
    ssl_verify_mode = ":verify_none"
  }
}

resource "null_resource" "ProvisionRemoteHosts" {
  count = "${var.instance_count}"
  connection {
    type = "ssh"
    user = "${var.ssh_user_name}"
    host = "${element(aws_instance.web.*.public_ip, count.index)}"
    private_key = "${file("${var.ssh_key_path}")}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo chef-client"
    ]
  }
}

