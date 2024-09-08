# Jenkins with ECS with Presistent Volume using EFS system.
# How to deploy this project using CloudFormation

## Prerequisites

1. AWS Account
2. Basic Understanding of AWS services (VPC, EFS, ECS, IAM)
3. Docker and Docker Compose
4. Basic understanding of the CloudFormation template
5. AWS CLI

## STEPS





- **We need a Dockerfile to customize our Jenkins image. Create a Dockerfile:**
- Create a folder for your project and inside that folder create a file named `Dockerfile` and paste the following into the Dockerfile:

   ```Dockerfile
   FROM amazonlinux:2023
   RUN yum install -y \
       python3 \
       python3-pip \
       git \
       zip \
       unzip \
       tar \
       gzip \
       wget \
       jq \
       which \
       findutils \
       python3-pip && \
       python3 -m pip install awscli && \
       python3 -m pip install boto3 && \
       wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo && \
       rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key && \
       yum upgrade -y && \
       yum install -y fontconfig && \
       dnf install java-17-amazon-corretto -y && \
       yum install -y jenkins && \
       yum clean all
   EXPOSE 8080
   CMD ["java", "-jar", "/usr/share/java/jenkins.war"]
   ```

- **Create a CloudFormation file for deploying our infrastructure:**
- Create a file named `main.yaml` and paste the following into the YAML template one by one:

   ```yaml
   AWSTemplateFormatVersion: '2010-09-09'
   Description: 'CloudFormation template for VPC with 3 public and 3 private subnets'
   ```
- Create a Parameter for Image URL of jenkins image
```yaml
Parameters:
  ImageURL:
    Type: String
    Description: 'Image URL for the ECR repo'
    Default: 'image-uri'
```
- We then create a VPC in the `Resources` section:

   ```yaml
   Resources:
       VPC:
           Type: AWS::EC2::VPC
           Properties:
               CidrBlock: 10.0.0.0/16
               EnableDnsHostnames: true
               EnableDnsSupport: true
               InstanceTenancy: default
               Tags:
                   - Key: Name
                     Value: project-vpc
   ```

- We then create an Internet Gateway and Internet Gateway attachment:

   ```yaml
       InternetGateway:
           Type: AWS::EC2::InternetGateway
       InternetGatewayAttachment:
           Type: AWS::EC2::VPCGatewayAttachment
           Properties:
               VpcId: !Ref VPC
               InternetGatewayId: !Ref InternetGateway
   ```

- We create 3 Public Subnets and 3 Private Subnets for the VPC for EFS and ECS to be available in different AZs:

   ```yaml
       PublicSubnet1:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 0, !GetAZs '' ]
               CidrBlock: 10.0.1.0/24
               MapPublicIpOnLaunch: true
               Tags:
                   - Key: Name
                     Value: project-subnet-public1-us-east-1a
       PublicSubnet2:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 1, !GetAZs '' ]
               CidrBlock: 10.0.2.0/24
               MapPublicIpOnLaunch: true
               Tags:
                   - Key: Name
                     Value: project-subnet-public2-us-east-1b
       PublicSubnet3:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 2, !GetAZs '' ]
               CidrBlock: 10.0.3.0/24
               MapPublicIpOnLaunch: true
               Tags:
                   - Key: Name
                     Value: project-subnet-public3-us-east-1c
       PrivateSubnet1:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 0, !GetAZs '' ]
               CidrBlock: 10.0.4.0/24
               MapPublicIpOnLaunch: false
               Tags:
                   - Key: Name
                     Value: project-subnet-private1-us-east-1a
       PrivateSubnet2:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 1, !GetAZs '' ]
               CidrBlock: 10.0.5.0/24
               MapPublicIpOnLaunch: false
               Tags:
                   - Key: Name
                     Value: project-subnet-private2-us-east-1b
       PrivateSubnet3:
           Type: AWS::EC2::Subnet
           Properties:
               VpcId: !Ref VPC
               AvailabilityZone: !Select [ 2, !GetAZs '' ]
               CidrBlock: 10.0.6.0/24
               MapPublicIpOnLaunch: false
               Tags:
                   - Key: Name
                     Value: project-subnet-private3-us-east-1c
   ```

- We are creating a Public Route Table and its association for the Public Subnet:

   ```yaml
       PublicRouteTable:
           Type: AWS::EC2::RouteTable
           Properties:
               VpcId: !Ref VPC
               Tags:
                   - Key: Name
                     Value: project-rtb-public
       DefaultPublicRoute:
           Type: AWS::EC2::Route
           DependsOn: InternetGatewayAttachment
           Properties:
               RouteTableId: !Ref PublicRouteTable
               DestinationCidrBlock: 0.0.0.0/0
               GatewayId: !Ref InternetGateway
       PublicSubnet1RouteTableAssociation:
           Type: AWS::EC2::SubnetRouteTableAssociation
           Properties:
               RouteTableId: !Ref PublicRouteTable
               SubnetId: !Ref PublicSubnet1
       PublicSubnet2RouteTableAssociation:
           Type: AWS::EC2::SubnetRouteTableAssociation
           Properties:
               RouteTableId: !Ref PublicRouteTable
               SubnetId: !Ref PublicSubnet2
       PublicSubnet3RouteTableAssociation:
           Type: AWS::EC2::SubnetRouteTableAssociation
           Properties:
               RouteTableId: !Ref PublicRouteTable
               SubnetId: !Ref PublicSubnet3
   ```

- We create a NAT Gateway for the EIP and its association for the public subnet and Internet Gateway:

   ```yaml
       NATGateway1:
           Type: AWS::EC2::NatGateway
           Properties:
               AllocationId: !GetAtt NATGateway1EIP.AllocationId
               SubnetId: !Ref PublicSubnet1
       NATGateway1EIP:
           Type: AWS::EC2::EIP
           DependsOn: InternetGatewayAttachment
           Properties:
               Domain: vpc
   ```

- Now we create a NAT Gateway and its association for the Private Subnet:

   ```yaml
       PrivateRouteTable1:
           Type: AWS::EC2::RouteTable
           Properties:
               VpcId: !Ref VPC
               Tags:
                   - Key: Name
                     Value: project-rtb-private1-us-east-1a
       DefaultPrivateRoute1:
           Type: AWS::EC2::Route
           Properties:
               RouteTableId: !Ref PrivateRouteTable1
               DestinationCidrBlock: 0.0.0.0/0
               NatGatewayId: !Ref NATGateway1
       PrivateSubnet1RouteTableAssociation:
           Type: AWS::EC2::SubnetRouteTableAssociation
           Properties:
               RouteTableId: !Ref PrivateRouteTable1
               SubnetId: !Ref PrivateSubnet1
   ```

   (Repeat similar blocks for PrivateRouteTable2 and PrivateRouteTable3)

- We will be creating the ECS and EFS security group and associate it with the VPC that we have just created. We will be opening port `8080` on the ECS security group for Jenkins and `2049` for the ECS Security group for the NFS file system of EFS, allowing `ALL` traffic in outbound:

   ```yaml
       ECSSecurityGroup:
           Type: AWS::EC2::SecurityGroup
           Properties:
               GroupDescription: "ECS Security Group"
               VpcId: !Ref VPC
               SecurityGroupIngress:
                   - IpProtocol: tcp
                     FromPort: 8080
                     ToPort: 8080
                     CidrIp: 0.0.0.0/0
               SecurityGroupEgress:
                   - IpProtocol: "-1"
                     CidrIp: 0.0.0.0/0
       EFSSecurityGroup:
           Type: AWS::EC2::SecurityGroup
           Properties:
               GroupDescription: "EFS Security Group"
               VpcId: !Ref VPC
               SecurityGroupIngress:
                   - IpProtocol: tcp
                     FromPort: 2049
                     ToPort: 2049
                     SourceSecurityGroupId: !Ref ECSSecurityGroup
               SecurityGroupEgress:
                   - IpProtocol: "-1"
                     CidrIp: 0.0.0.0/0
   ```
- We will be creating  IAM policies and role for the ecs to execute  and efs mount 
```yaml

  # Policy for ECS Task
  ECSTaskPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: ecstaskpolicy
      PolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Action:
              - ecr:GetAuthorizationToken
              - ecr:BatchCheckLayerAvailability
              - ecr:GetDownloadUrlForLayer
              - ecr:BatchGetImage
              - logs:CreateLogStream
              - logs:PutLogEvents
            Resource: "*"
      Roles:
        - !Ref ECSEFSmountTaskRole

  # Policy for EFS Mount
  EFSMountPolicy:
    Type: AWS::IAM::Policy
    Properties:
      PolicyName: efsmountpolicy
      PolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Sid: AllowDescribe
            Effect: Allow
            Action:
              - elasticfilesystem:DescribeAccessPoints
              - elasticfilesystem:DescribeFileSystems
              - elasticfilesystem:DescribeMountTargets
              - ec2:DescribeAvailabilityZones
            Resource: "*"
          - Sid: AllowCreateAccessPoint
            Effect: Allow
            Action:
              - elasticfilesystem:CreateAccessPoint
            Resource: "*"
            Condition:
              Null:
                aws:RequestTag/efs.csi.aws.com/cluster: false
              ForAllValues:StringEquals:
                aws:TagKeys: efs.csi.aws.com/cluster
          - Sid: AllowTagNewAccessPoints
            Effect: Allow
            Action:
              - elasticfilesystem:TagResource
            Resource: "*"
            Condition:
              StringEquals:
                elasticfilesystem:CreateAction: CreateAccessPoint
              Null:
                aws:RequestTag/efs.csi.aws.com/cluster: false
              ForAllValues:StringEquals:
                aws:TagKeys: efs.csi.aws.com/cluster
          - Sid: AllowDeleteAccessPoint
            Effect: Allow
            Action: elasticfilesystem:DeleteAccessPoint
            Resource: "*"
            Condition:
              Null:
                aws:ResourceTag/efs.csi.aws.com/cluster: false
      Roles:
        - !Ref ECSEFSmountTaskRole

  # IAM Role for ECS Tasks
  ECSEFSmountTaskRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: ECSEFSmountTaskRole
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Principal:
              Service: ecs-tasks.amazonaws.com
            Action: sts:AssumeRole
      Policies:
        - PolicyName: ECSTaskPolicy
          PolicyDocument:
            Version: "2012-10-17"
            Statement:
              - Effect: Allow
                Action:
                  - ecr:GetAuthorizationToken
                  - ecr:BatchCheckLayerAvailability
                  - ecr:GetDownloadUrlForLayer
                  - ecr:BatchGetImage
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource: "*" 
```
- We will be creating the EFS file system:

   ```yaml
       EFSSystem:
           Type: AWS::EFS::FileSystem
           Properties:
               Encrypted: true
               FileSystemTags:
                   - Key: Name
                     Value: JenkinsEFS
   ```

- We need to mount the target for the EFS. For that, we will be using the public subnets `1, 2, 3` that we have just created:

   ```yaml
       JenkinsHomeVolume1:
           Type: AWS::EFS::MountTarget
           Properties:
               FileSystemId: !Ref EFSSystem
               SubnetId: !Ref PublicSubnet1
               SecurityGroups:
                   - !Ref EFSSecurityGroup
       JenkinsHomeVolume2:
           Type: AWS::EFS::MountTarget
           Properties:
               FileSystemId: !Ref EFSSystem
               SubnetId: !Ref PublicSubnet2
               SecurityGroups:
                   - !Ref EFSSecurityGroup
       JenkinsHomeVolume3:
           Type: AWS::EFS::MountTarget
           Properties:
               FileSystemId: !Ref EFSSystem
               SubnetId: !Ref PublicSubnet3
               SecurityGroups:
                   - !Ref EFSSecurityGroup
   ```

- We create an ECS cluster for our application:

   ```yaml
       ECSCluster:
           Type: AWS::ECS::Cluster
           Properties:
               ClusterName: JenkinsCluster
               CapacityProviders:
                   - FARGATE
                   - FARGATE_SPOT
               DefaultCapacityProviderStrategy:
                   - CapacityProvider: FARGATE
                     Weight: 1
                   - CapacityProvider: FARGATE_SPOT
                     Weight: 1
               Configuration:
                   ExecuteCommandConfiguration:
                       Logging: DEFAULT
   ```

- Create a Log group to fetch the log stream of EFS:

   ```yaml
       ECSLogGroup:
           Type: AWS::Logs::LogGroup
           Properties:
               LogGroupName: !Sub "/ecs/test-${AWS::StackName}"
               RetentionInDays: 7
   ```

- **Now we are creating the ECS task definition. Comment the *CpuArchitecture* if you are using intel or amd chip (64-bit)** 
   ```yaml

  ECSTaskDefinition:
    Type: AWS::ECS::TaskDefinition
    Properties:
      ExecutionRoleArn: !Ref ECSEFSmountTaskRole
      TaskRoleArn: !Ref ECSEFSmountTaskRole
      NetworkMode: awsvpc
      RequiresCompatibilities:
        - FARGATE
      RuntimePlatform:
        OperatingSystemFamily: LINUX
        CpuArchitecture: ARM64
      Family: my-jenkins-task-00
      Cpu: "1024"
      Memory: "2048"
      ContainerDefinitions:
        - Name: jenkins
          Image: !Ref ImageURL
          Cpu: 1024
          Memory: 2048
          MemoryReservation: 1024
          Essential: true
          PortMappings:
            - ContainerPort: 8080
              Protocol: tcp
          LinuxParameters:
            InitProcessEnabled: true
          MountPoints:
            - SourceVolume: efs-volume
              ContainerPath: /root/.jenkins
          LogConfiguration:
            LogDriver: awslogs
            Options:
              mode: non-blocking
              max-buffer-size: 25m
              awslogs-group: !Ref ECSLogGroup
              awslogs-region: us-east-1
              awslogs-create-group: "true"
              awslogs-stream-prefix: efs-task
      Volumes:
        - Name: efs-volume
          EFSVolumeConfiguration:
            FilesystemId: !Ref EFSSystem
            RootDirectory: /
            TransitEncryption: ENABLED

- Create a ecs service
```yaml
  ECSService:
    Type: AWS::ECS::Service
    Properties:
      Cluster: !Ref ECSCluster  
      TaskDefinition: !Ref ECSTaskDefinition
      LaunchType: FARGATE
      ServiceName: ebs
      SchedulingStrategy: REPLICA
      DesiredCount: 1
      NetworkConfiguration:
        AwsvpcConfiguration:
          AssignPublicIp: ENABLED
          SecurityGroups: 
            - !Ref ECSSecurityGroup
          Subnets:
            - !Ref PublicSubnet1
            - !Ref PublicSubnet2
            - !Ref PublicSubnet3
      PlatformVersion: LATEST
      DeploymentConfiguration:
        MaximumPercent: 200
        MinimumHealthyPercent: 100
        DeploymentCircuitBreaker:
          Enable: true
          Rollback: true
      DeploymentController:
        Type: ECS
      Tags: []
      EnableECSManagedTags: true
```
**Create the bash script and update the Repository Name, aws region and stack name if you desire and required**

```bash
#!/bin/bash

# update the stack name
STACK_NAME="jenkins-efs-ecs"
# update to your desired aws region
AWS_REGION="us-east-1"

# Set or update the repository name
REPOSITORY_NAME="jenkins"

# Set the image tag
IMAGE_TAG="latest"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output --region $AWS_REGION)
# Create the ECR repository
aws ecr describe-repositories --repository-names "${REPOSITORY_NAME}" --region $AWS_REGION > /dev/null 2>&1
if [ $? -ne 0 ]
then
    aws ecr create-repository --repository-name "${REPOSITORY_NAME}" --region $AWS_REGION > /dev/null
fi


# Build the Docker image
docker build -t $REPOSITORY_NAME:$IMAGE_TAG .

# Get the ECR login command
LOGIN_COMMAND=$(aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com)
# Push the image to ECR
docker tag $REPOSITORY_NAME:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG

# Export the image URI as an environment variable
IMAGE_URI=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG

aws cloudformation create-stack \
  --stack-name $STACK_NAME \
  --template-body file://main.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides ImageURL=$IMAGE_URI
```

- Go to the AWS Console Dashboard navigate to Cloudformation and click on `jenkins-ecs-efs` see the creation process after stack creation is complete go to ecs click on service and click on task access jenkins with the public ip:8080
