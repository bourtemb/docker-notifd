# docker pull i386/debian

FROM i386/debian:wheezy-slim as base_stage

# Define the build stage
FROM base_stage AS build_stage

RUN apt-get update && apt-get install -y --no-install-recommends build-essential \
    libomniorb4-dev \
    libcos4-dev \
    omniidl \
    omniorb-idl \
    wget \
    apt-utils

RUN wget --no-check-certificate "http://downloads.sourceforge.net/project/omninotify/omninotify/omniNotify%202.1/omniNotify-2.1.tar.gz" --directory-prefix=/tmp/omninotify
WORKDIR /tmp/omninotify
RUN tar xzf omniNotify-2.1.tar.gz
WORKDIR omniNotify
# Some patches are needed (iostream.h => <iostream> + using namespace std;)
ADD omninotify.patch /tmp
RUN patch -p1 -i /tmp/omninotify.patch

WORKDIR build
# The examples compilation will fail. This is expected, not patch was provided for them
# But we don't need them anyway 
RUN ../configure --with-omniorb=/usr --prefix=/usr && \ 
    make || \
    make install

FROM base_stage as release_stage

ARG tango_host

# Install libtango7 & Tango Starter (to get notifd2db)
RUN apt-get update && echo "$tango_host" | apt-get install -y --no-install-recommends tango-starter
RUN apt-get update && apt-get install -y --no-install-recommends procps
# RUN apt-get update && apt-get install -y tango-starter

# Adapt notify_daemon script to keep the notifd in foreground
ADD notify_daemon /usr/lib/tango/notify_daemon

# Bring across the notifd binary (and all the needed libraries?)
COPY --from=build_stage /usr/bin/notifd /usr/bin/notifd 
COPY --from=build_stage /usr/lib/lib*Not* /usr/lib/

CMD /usr/lib/tango/notify_daemon

# You can build using a command like:
# docker build --build-arg tango_host=myhost:20000 -t wheezy-notifd .
# Start notifd - eventually override TANGO_HOST env variable
# docker run --network host --env TANGO_HOST=myhost:10000 wheezy-notifd /usr/lib/tango/notify_daemon

