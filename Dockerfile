ARG BASE_IMAGE
FROM ${BASE_IMAGE:-ubuntu:xenial}
MAINTAINER BigStream Solutions, Inc.
# Metadata for App
#ARG DEVICE=U200
#ADD AppDef.json /etc/NAE/AppDef.json
#RUN  sed -i "s/REPLACE_WITH_TYPE/$CARD_TYPE/" /etc/NAE/AppDef.json \
# This is a tsting
#     &&  curl --fail -X POST -d @/etc/NAE/AppDef.json https://api.jarvice.com/jarvice/validate
# FPGA platform
# Install Xilinx runtime
#ADD xrt_2.1.0_16.04.deb /xrt_2.1.0_16.04.deb
#RUN apt-get -y update && \
#    apt-get install -y --allow-downgrades --reinstall /*.deb && \
#    rm /*.deb

RUN apt-get update \
    && apt-get install -y --no-install-recommends gnupg2 apt-utils \
	&& rm -rf /var/lib/apt/lists/*
#
# Bigstream start here
#   This Dockerfile is provided by Nimbix.  We build our docker image based on it.
#
# create bigstream user
ARG USER=bigstream
ENV SRC   /home/${USER}/packages
RUN useradd -m -p 4tCWWORg3ltEE -s /bin/bash $USER
RUN mkdir -p $SRC && chown -R $USER:$USER $SRC

# Install depended package
RUN . /etc/lsb-release \
    && echo "deb http://ppa.launchpad.net/ubuntu-toolchain-r/test/ubuntu $DISTRIB_CODENAME main" >> /etc/apt/sources.list \
	&& apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 60C317803A41BA51845E371A1E9377A2BA9EF27F
# sbt
RUN echo "deb http://dl.bintray.com/sbt/debian /" >> /etc/apt/sources.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 2EE0EA64E40A89B84B2DF73499E82A75642AC823

#
# required by axstreamBigD/distribution_scripts/build_all.sh logic to handle LZMA installation
ARG GCC_VERSION=4.9
ARG JDK=openjdk-8-jdk
RUN apt-get update \
	&& apt install -y --no-install-recommends vim wget git build-essential gdb gdbserver make zlib1g-dev \
        libgtest-dev sbt bison flex  xz-utils $JDK curl libssl-dev curl libcurl4-openssl-dev \
	&& rm -rf /var/lib/apt/lists/*

# Install ANT
ARG ANT_VERSION=1.9.6
RUN curl -sL --retry 3 "http://archive.apache.org/dist/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz" \
    | gunzip | tar x -C /opt \
    && ln -sfn /opt/apache-ant-${ANT_VERSION}/bin/ant /usr/bin/ant \
    && echo "Done with installing ant!"

# Install maven
ARG MAVEN_VERSION=3.3.9
RUN curl -sL --retry 3 \
    "http://apache.mirrors.tds.net/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    | gunzip | tar x -C /usr/share/ \
    && ln -s /usr/share/apache-maven-${MAVEN_VERSION} /usr/share/maven \
    && echo "Done with installing maven!"

# Install scala
ARG SCALA_VERSION=2.11.8
RUN wget www.scala-lang.org/files/archive/scala-${SCALA_VERSION}.deb -O $SRC/scala-${SCALA_VERSION}.deb \
    && dpkg -i $SRC/scala-${SCALA_VERSION}.deb \
    && rm -f $SRC/scala-${SCALA_VERSION}.deb \
    &&  echo "Done with installing scala!"

# Install cmake
# Edit bootstrap to enable system curl
# Edit the file "CMakeCache.txt" and make the following changes
#   1) CMAKE_C_FLAGS=-I/usr/include/openssl
#   2) CMAKE_USE_OPENSSL:BOOL=ON
ARG CMAKE_VERSION=3.5.2
RUN . /etc/lsb-release \
    && if [ "${DISTRIB_RELEASE%.*}" -gt '16' ]; then CMAKE_VERSION=3.14.5 ; fi \
    && curl -sL --retry 3 "https://cmake.org/files/v${CMAKE_VERSION%.*}/cmake-${CMAKE_VERSION}.tar.gz" | gunzip | tar x -C /opt/ \
    && cd /opt/cmake-${CMAKE_VERSION}/ \
    && sed -i "s/cmake_options=\"-DCMAKE_BOOTSTRAP=1\"/cmake_options=\"-DCMAKE_BOOTSTRAP=1 -DCMAKE_USE_OPENSSL=ON\"/" bootstrap \
    && ./bootstrap --system-curl \
    && sed -i "s/CMAKE_C_FLAGS:STRING=/CMAKE_C_FLAGS:STRING=-I\/usr\/include\/openssl/" CMakeCache.txt \
    && sed -i "s/CMAKE_USE_OPENSSL:BOOL=OFF/CMAKE_USE_OPENSSL:BOOL=ON/" CMakeCache.txt \
    && make \
    && make install \
    && cd  && rm -rf /opt/cmake-${CMAKE_VERSION}/ \
    && echo "Done with installing cmake with openssl support!"
