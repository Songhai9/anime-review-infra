FROM hashicorp/terraform:1.13 AS terraform
FROM python:3.13-slim

RUN apt-get update \
    && apt-get install -y \
      jq \
      openssh-client \
      ca-certificates \
      unzip \
      curl \
      git \
    && rm -rf /var/lib/apt/lists/*

COPY --from=terraform /bin/terraform /usr/local/bin/terraform

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "/tmp/awscliv2.zip" \
    && unzip /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

RUN curl \
    "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
    -o /tmp/session-manager-plugin.deb \
    && dpkg -i /tmp/session-manager-plugin.deb \
    && rm /tmp/session-manager-plugin.deb

RUN pip install --no-cache-dir \
    ansible \
    boto3 \
    botocore

RUN terraform version \
    && ansible --version \
    && aws --version \
    && session-manager-plugin --version \
    && jq --version