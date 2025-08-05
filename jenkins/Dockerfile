FROM jenkins/jenkins:lts
USER root
RUN apt-get update && \
    apt-get install -y awscli docker.io && \
    usermod -aG docker jenkins
USER jenkins