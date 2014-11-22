FROM      ubuntu:14.04
MAINTAINER Arief Hidayat <mr.arief.hidayat@gmail.com>

# Install Oracle Java 7 (jhipster using Java 8, Grails 2.3.x uses Java 7)
ENV JAVA_VER 7
ENV JAVA_HOME /usr/lib/jvm/java-7-oracle
ENV GRAILS_VERSION 2.3.11
ENV GRAILS_REPO grails-practice
ENV GRAILS_REPO_VERSION 0.1

# make sure the package repository is up to date
RUN echo "deb http://archive.ubuntu.com/ubuntu trusty main universe" > /etc/apt/sources.list
RUN apt-get -y update


# install python-software-properties (so you can do add-apt-repository)
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y -q python-software-properties software-properties-common

# install SSH server so we can connect multiple times to the container
RUN apt-get -y install openssh-server && mkdir /var/run/sshd

# >> a bit different way to install JDK from https://registry.hub.docker.com/u/tifayuki/java/
RUN echo 'deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main' >> /etc/apt/sources.list && \
    echo 'deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main' >> /etc/apt/sources.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C2518248EEA14886 && \
    apt-get update && \
    echo oracle-java${JAVA_VER}-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections && \
    apt-get install -y --force-yes --no-install-recommends oracle-java${JAVA_VER}-installer oracle-java${JAVA_VER}-set-default && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists && \
    rm -rf /var/cache/oracle-jdk${JAVA_VER}-installer

# Set oracle java as the default java
RUN update-java-alternatives -s java-${JAVA_VER}-oracle
RUN echo "export JAVA_HOME=/usr/lib/jvm/java-${JAVA_VER}-oracle" >> ~/.bashrc

# >> from https://github.com/onesysadmin/docker-gvm
ENTRYPOINT ["gvm-exec.sh"]
# gvm requires curl and unzip
RUN apt-get update && \
    apt-get install -yqq --no-install-recommends curl unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# install gvm
RUN curl -s get.gvmtool.net | bash
ADD gvm.config /.gvm/etc/config
ADD bin/ /usr/local/bin/

CMD ["grails"]
# Set default Grails Java Runtime env
ENV JAVA_OPTS -Xms256m -Xmx512m -XX:MaxPermSize=256m -Djetty.serverHost=0.0.0.0
# install newest version of grails 2.3.x
RUN gvm-wrapper.sh install grails ${GRAILS_VERSION} && gvm-wrapper.sh flush archives && gvm-exec.sh grails help

# install utilities
RUN apt-get -y install vim git sudo zip bzip2 fontconfig curl

# install maven
RUN apt-get -y install maven

# install node.js from PPA
RUN add-apt-repository ppa:chris-lea/node.js
RUN apt-get update
RUN apt-get -y install nodejs

# install yeoman
RUN npm install -g yo

# configure the "hida" and "root" users
RUN echo 'root:hida' |chpasswd
RUN groupadd hida && useradd hida -s /bin/bash -m -g hida -G hida && adduser hida sudo
RUN echo 'hida:hida' |chpasswd

# install the sample app to download all Maven dependencies
RUN cd /home/hida && \
    wget https://github.com/arief-hidayat/${GRAILS_REPO}/archive/v${GRAILS_REPO_VERSION}.zip && \
    unzip v${GRAILS_REPO_VERSION}.zip && \
    rm v${GRAILS_REPO_VERSION}.zip
RUN cd /home/hida/${GRAILS_REPO}-${GRAILS_REPO_VERSION} && npm install
RUN cd /home && chown -R hida:hida /home/hida
RUN cd /home/hida/${GRAILS_REPO}-${GRAILS_REPO_VERSION} && sudo -u hida grails clean && sudo -u hida grails compile

# expose the working directory, the Tomcat port, the Grunt server port, the SSHD port, and run SSHD
VOLUME ["/hida"]
EXPOSE 8080
EXPOSE 9000
EXPOSE 22
CMD    /usr/sbin/sshd -D
