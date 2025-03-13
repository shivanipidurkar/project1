provider "aws" {
  region = "us-east-1"  # Specify your desired region
}

resource "aws_iam_policy" "eks_create_policy" {
  name        = "EKSCreateClusterPolicy"
  description = "Policy to create EKS cluster"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "eks:CreateCluster"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "eks_tag_resource_policy" {
  name        = "EKSCreateAndTagPolicy"
  description = "Custom policy to allow EKS cluster creation and tagging"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "eks:CreateCluster",
          "eks:TagResource"
        ]
        Resource = "arn:aws:eks:us-east-1:688567260528:cluster/project-eks"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_eks_tag_policy" {
  role       = "Project3tier"
  policy_arn = aws_iam_policy.eks_tag_resource_policy.arn
}


resource "aws_iam_role_policy_attachment" "attach_eks_create_policy" {
  role       = "Project3tier"
  policy_arn = aws_iam_policy.eks_create_policy.arn
}


 #Creating IAM role for EKS
  resource "aws_iam_role" "master" {
    name = "veera-eks-master"

    assume_role_policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "eks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    })
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    role       = aws_iam_role.master.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
    role       = aws_iam_role.master.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    role       = aws_iam_role.master.name
  }

  resource "aws_iam_role" "worker" {
    name = "veera-eks-worker"

    assume_role_policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    })
  }

  resource "aws_iam_policy" "autoscaler" {
    name = "veera-eks-autoscaler-policy"
    policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:DescribeTags",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:SetDesiredCapacity",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "ec2:DescribeLaunchTemplateVersions"
          ],
          "Effect": "Allow",
          "Resource": "*"
        }
      ]
    })
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonSSMManagedInstanceCore" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "s3" {
    policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_role_policy_attachment" "autoscaler" {
    policy_arn = aws_iam_policy.autoscaler.arn
    role       = aws_iam_role.worker.name
  }

  resource "aws_iam_instance_profile" "worker" {
    depends_on = [aws_iam_role.worker]
    name       = "veera-eks-worker-new-profile"
    role       = aws_iam_role.worker.name
  }
 
 # data source 
 data "aws_vpc" "main" {
  tags = {
    Name = "Jumphost-vpc"  # Specify the name of your existing VPC
  }
}

data "aws_subnet" "subnet-1" {
 vpc_id = data.aws_vpc.main.id 
 filter {
    name = "tag:Name"
    values = ["Jumphost-subnet1"]
 }
}

data "aws_subnet" "subnet-2" {
 vpc_id = data.aws_vpc.main.id 
 filter {
    name = "tag:Name"
    values = ["Jumphost-subnet2"]
 }
}
data "aws_security_group" "selected" {
  vpc_id = data.aws_vpc.main.id 
  filter {
    name = "tag:Name"
    values = ["Jumphost-sg"]
 }
}

 #Creating EKS Cluster
  resource "aws_eks_cluster" "eks" {
    name     = "project-eks"
    role_arn = aws_iam_role.master.arn

    vpc_config {
      subnet_ids = [data.aws_subnet.subnet-1.id, data.aws_subnet.subnet-2.id]
    }

    tags = {
      "Name" = "MyEKS"
    }

    depends_on = [
      aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
      aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
      aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
    ]
  }
 resource "aws_eks_node_group" "node-grp" {
    cluster_name    = aws_eks_cluster.eks.name
    node_group_name = "project-node-group"
    node_role_arn   = aws_iam_role.worker.arn
    subnet_ids      = [data.aws_subnet.subnet-1.id, data.aws_subnet.subnet-2.id]
    capacity_type   = "ON_DEMAND"
    disk_size       = 20
    instance_types  = ["t2.medium"]

    remote_access {
      ec2_ssh_key               = "provisioner"
      source_security_group_ids = [data.aws_security_group.selected.id]
    }

    labels = {
      env = "dev"
    }

    scaling_config {
      desired_size = 2
      max_size     = 4
      min_size     = 1
    }

    update_config {
      max_unavailable = 1
    }

    depends_on = [
      aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
      aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
      aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    ]
  }
