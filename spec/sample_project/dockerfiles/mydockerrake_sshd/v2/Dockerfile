FROM ubuntu:12.04

ENV DEBIAN_FRONTEND noninteractive

RUN echo 'root:root' | chpasswd
RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y openssh-server supervisor

RUN mkdir /var/run/sshd
ADD supervisord/main.conf /etc/supervisor/conf.d/main.conf
ADD supervisord/sshd.conf /etc/supervisor/conf.d/sshd.conf
RUN chown root:root -R    /etc/supervisor/conf.d/ ; \
  mkdir -p /var/log/supervisor

CMD ["/usr/bin/supervisord", "-n"]
EXPOSE 22 9001
