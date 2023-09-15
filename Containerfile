FROM fedora:38 AS base

LABEL maintainer="Konrad Kleine <kkleine@redhat.com>"
LABEL author="Konrad Kleine <kkleine@redhat.com>"
ENV LANG=en_US.utf8

RUN dnf install -y \
    icecream \
    htop \
    iputils \
    iproute \
   && yum clean all

ENV HOME=/home/icecc
WORKDIR $HOME
RUN mkdir -p /home/icecc && \
    chown icecc:icecc /home/icecc -Rv

# About the "netname" below:

# "You might designate a netname. This is useful if your network is using VPN
# to make it seem like developers who are physically a long distance apart seem
# like they are on the same sub-net. While the VPNs are useful, they typically
# do not have enough bandwidth for icecream, so by setting a different netname
# on each side of the VPN you can save bandwidth. Netnames can be used to work
# around some limitations above: if a netname is set icecream schedulers and
# daemons will ignore the existence of other schedulers and daemons."
#
# (Source: https://github.com/icecc/icecream#some-advice-on-configuration)

# ------------------------------------------------------------------------------

FROM base AS scheduler

LABEL description="An icecream scheduler image based on Fedora that we use in our compile farm"

ENTRYPOINT [\
  "icecc-scheduler", \
  "--port", "8765", \
  "--user-uid", "icecc", \
  "-vvv" \
]
CMD [\
  "--netname", "schedulernetname" \
]

# See https://github.com/icecc/icecream#network-setup-for-icecream-firewalls

EXPOSE \
  8765/tcp \
  8766/tcp

# https://docs.docker.com/engine/reference/builder/#healthcheck
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://0.0.0.0:8765/ || exit 1

# ------------------------------------------------------------------------------

FROM base AS daemon

LABEL description="An icecream daemon image based on Fedora that we use in our compile farm"

RUN mkdir -pv /home/icecc/{env-basedir,logs}

# Define how to start icecc by default
# (see "man icecc" for more information)
ENTRYPOINT [\
  "iceccd", \
  "--user-uid", "icecc", \
  "--cache-limit", "200", \
  "--scheduler-host", "10.0.101.32", \
  "--env-basedir", "/home/icecc/env-basedir", \
  "--user-uid", "icecc", \
  "--netname", "daemonnetname", \
  "-vvv" \
]

# "--log-file", "/home/icecc/logs/iceccd.log", \

CMD [\
  "--nice", "5", \
  "--max-processes", "5", \
  "-N", "kkleineNODE" \
]

# See https://github.com/icecc/icecream#network-setup-for-icecream-firewalls

EXPOSE \
  10245/tcp \
  8766/tcp \
  8765/udp \
  8766/tcp

# VOLUME /home/icecc/envs

# https://docs.docker.com/engine/reference/builder/#healthcheck
HEALTHCHECK --interval=5m --timeout=3s \
   CMD curl -f http://0.0.0.0:10245/ || exit 1

COPY data/etc/sysconfig/icecream /etc/sysconfig/icecream
