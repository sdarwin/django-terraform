
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
  tags = {
    Name = "${var.environment}-web"
  }

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
      private_key = "${file("${var.ssh_key_path}")}"
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
        "gitkey",
        "auth"
      ]
    }
    EOF

    #environment     = "production"
    use_policyfile = true
    policy_group = "${var.environment}"
    policy_name = "django-website"
    #log_to_file = true
    client_options  = ["chef_license 'accept'"]
    run_list        = ["cookbook::recipe"]
    node_name       = "web${count.index}"
    #secret_key      = "${file("../encrypted_data_bag_secret")}"
    #server_url      = "https://chef.company.com/organizations/org1"
    server_url      = "https://chefserver/organizations/testorg"
    recreate_client = true
    user_name       = "sdarwin"
    user_key        = "${file("~/.chef/sdarwin.pem")}"
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

resource "aws_lb" "django" {
  name               = "django-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.lb_sg.id}"]
  subnets            = ["${aws_default_subnet.public-1a.id}", "${aws_default_subnet.public-1b.id}", "${aws_default_subnet.public-1c.id}"]

  tags = {
    Environment = "${var.environment}"
  }
}

resource "aws_security_group" "lb_sg" {
  name        = "django_lb_${var.environment}"
  description = "django_lb"
  #vpc_id      = "${aws_vpc.main.id}"

  ingress {
    # TLS (change to whatever ports you need)
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group_attachment" "test" {
  count = "${var.instance_count}"
  target_group_arn = "${aws_lb_target_group.test.arn}"
  #target_id        = "${aws_instance.test.id}"
  target_id        =  "${element(aws_instance.web.*.id, count.index)}"
  port             = "443"
}

resource "aws_lb_target_group" "test" {
  name     = "test-${var.environment}"
  port     = "443"
  protocol = "HTTPS"
  vpc_id   = "${aws_default_vpc.default.id}"
  health_check {
    path = "/polls"
    protocol = "HTTPS"
    matcher = "200,300,301,302,303"
  }
}

resource "aws_lb_listener" "lb-http" {
   load_balancer_arn = "${aws_lb.django.arn}"
   port = "443"
   protocol = "HTTPS"
   ssl_policy        = "ELBSecurityPolicy-2016-08"
   certificate_arn   = "arn:aws:acm:eu-central-1:130932026351:certificate/876c7f40-f090-4f60-ad84-84514271643d"

default_action {
     target_group_arn = "${aws_lb_target_group.test.arn}"
     type = "forward"
   }
}

resource "aws_default_subnet" "public-1a" {
  availability_zone = "eu-central-1a"
}

resource "aws_default_subnet" "public-1b" {
  availability_zone = "eu-central-1b"
}

resource "aws_default_subnet" "public-1c" {
  availability_zone = "eu-central-1c"
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}
