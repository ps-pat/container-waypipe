LABEL maintainer="Patrick Fournier p_fournier@hushmail.com"
FROM docker.io/alpine:3.23.3

RUN apk add --no-cache alpine-conf shadow openssh waypipe

ENV XDG_RUNTIME_DIR=/tmp
RUN useradd -m -d /home/user -p '*' -u 1000 -U user

ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 22
COPY entrypoint.sh /
COPY sshd_config /etc/ssh/sshd_config
