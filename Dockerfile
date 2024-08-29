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
    wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo && \
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key && \
    yum upgrade -y && \
    yum install -y fontconfig && \
    dnf install java-17-amazon-corretto -y && \
    yum install -y jenkins && \
    yum clean all 
EXPOSE 8080
CMD ["java", "-jar", "/usr/share/java/jenkins.war"]