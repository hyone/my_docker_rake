FROM hyone/rbenv:2.1

# docker
RUN wget -qO- https://get.docker.io/gpg | apt-key add - ; \
  echo deb http://get.docker.io/ubuntu docker main > /etc/apt/sources.list.d/docker.list ; \
  apt-get update ; \
  apt-get install -q -y lxc-docker-0.8.1

ADD . /app
