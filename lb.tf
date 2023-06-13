### ALB

# module "alb" {
#   source  = "terraform-aws-modules/alb/aws"
#   version = "~> 6.5"

#   http_tcp_listeners = [
#     {
#       port     = 80
#       protocol = "HTTP"
#     }
#   ]

#   load_balancer_type = "application"
#   name               = "boundary"
#   security_groups    = [aws_security_group.alb.id]
#   subnets            = local.public_subnets
#   tags               = local.tags
  
#   target_groups = [
#     {
#       name             = "boundary"
#       backend_protocol = "HTTP"
#       backend_port     = 9200
#     }
#   ]

#   vpc_id = local.vpc_id
# }

# resource "aws_security_group" "alb" {
#   egress {
#     cidr_blocks = ["0.0.0.0/0"]
#     from_port   = 0
#     protocol    = "-1"
#     to_port     = 0
#   }

#   dynamic "ingress" {
#     for_each = [80, 443]

#     content {
#       cidr_blocks = ["0.0.0.0/0"]
#       from_port   = ingress.value
#       protocol    = "TCP"
#       to_port     = ingress.value
#     }
#   }

#   name = "Boundary Application Load Balancer"

#   tags = merge(
#     {
#       Name = "Boundary Application Load Balancer"
#     },
#     var.tags
#   )

#   vpc_id = local.vpc_id
# }




########## NEW

resource "aws_lb" "controller" {
  # Truncate any characters of name that are longer than 32 characters which is the limit imposed by Amazon for the name of a load balancer
  #name               = "${substr("${var.tag}-controller-${random_pet.test.id}", 0, min(length("${var.tag}-controller-${random_pet.test.id}"), 32))}"
  name               = "boundary"
  load_balancer_type = "network"
  internal           = false
  #subnets            = local.public_subnets
  subnets            = aws_subnet.public.*.id

  tags = local.tags
}

resource "aws_route53_record" "boundary_lb" {
  zone_id = aws_route53_zone.selected.zone_id
  name    = "${var.name}.${var.dns_domain}"
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.controller.dns_name]
}


resource "aws_lb_target_group" "controller" {
  name     = "boundary-tg"
  port     = 9200
  protocol = "TCP"
  vpc_id   = local.vpc_id

  stickiness {
    enabled = false
    type    = "source_ip"
  }
  tags = local.tags
}

resource "aws_lb_target_group_attachment" "controller" {
  count            = var.controller_desired_capacity
  target_group_arn = aws_lb_target_group.controller.arn
  #target_id        = aws_instance.controller[count.index].id
  target_id        = aws_instance.server[count.index].id
  port             = 9200
}

resource "aws_lb_listener" "controller" {
  load_balancer_arn = aws_lb.controller.arn
  port              = "9200"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.controller.arn
  }
}

resource "aws_security_group" "controller_lb" {
  vpc_id = local.vpc_id

  tags = local.tags
}

resource "aws_security_group_rule" "allow_9200" {
  type              = "ingress"
  from_port         = 9200
  to_port           = 9200
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.controller_lb.id
}

resource "aws_security_group_rule" "allow_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.controller_lb.id
}

resource "aws_security_group_rule" "allow_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.controller_lb.id
}

resource "aws_security_group_rule" "allow_egress_lb" {
    type        = "egress" 
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    security_group_id = aws_security_group.controller_lb.id
  }