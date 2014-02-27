FROM ubuntu:12.04

ENV DEBIAN_FRONTEND noninteractive

RUN echo 'root:root' | chpasswd
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y openssh-server
RUN mkdir /var/run/sshd

CMD ["/usr/sbin/sshd", "-D"]
EXPOSE 22
