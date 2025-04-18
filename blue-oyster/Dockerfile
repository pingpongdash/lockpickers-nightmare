FROM alpine

##################################
# ARG to EV
ARG BLUE_OYSTER_UID
ARG BLUE_OYSTER_GID
ARG BLUE_OYSTER_USER
ARG BLUE_OYSTER_GROUP

##################################
# essentials
RUN apk upgrade && apk update && apk add --no-cache bash shadow fortune

##################################
# Match UID and GID
RUN groupadd -g ${BLUE_OYSTER_GID} ${BLUE_OYSTER_GROUP}
RUN useradd  -g ${BLUE_OYSTER_GROUP} -u ${BLUE_OYSTER_UID} -s /bin/bash -m ${BLUE_OYSTER_USER}

##################################
# setup
COPY dot.blue-oyster.sh /etc/bash/bashrc

RUN echo "" > /home/${BLUE_OYSTER_USER}/.hushlogin
WORKDIR /home/${BLUE_OYSTER_USER}
