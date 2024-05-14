FROM __BASEIMAGE_ARCH__/alpine
MAINTAINER Yewolf <yewolf@yewolf.fr>

__CROSS_COPY qemu-__QEMU_ARCH__-static /usr/bin
RUN apk --no-cache --update add bash tzdata openssl jq
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

WORKDIR /app
VOLUME /mnt/data

COPY certs-extraction.sh /app/certs-extraction.sh
COPY healthcheck /usr/bin/healthcheck
RUN chmod +x /usr/bin/healthcheck
RUN chmod +x /app/certs-extraction.sh

RUN export DOMAINS=$DOMAINS
CMD ["/bin/bash", "/app/certs-extraction.sh"]
