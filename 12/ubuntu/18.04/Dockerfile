FROM ubuntu:18.04

ARG CI_PIPELINE_URL
ARG GIT_HASH

LABEL Pipeline=$CI_PIPELINE_URL
LABEL GitHash=$GIT_HASH

ENV PG_VERSION="12"

RUN apt-get update && \
    apt-get -y install \
            locales \
            wget \
            ca-certificates \
            gnupg2 \
            lsb-release \
            less \
            jq

RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y install \
            postgresql-${PG_VERSION} \
            postgresql-contrib-${PG_VERSION} \
            postgresql-${PG_VERSION}-repack \
            pgbackrest && \
    apt-get -y purge wget lsb-release && apt-get -y autoremove

COPY fs/ /

RUN locale-gen && \
    mkdir -p /var/lib/postgresql/data && \
    chown postgres:postgres /var/lib/postgresql/data && \
    echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/${PG_VERSION}/main/pg_hba.conf && \
    echo "host replication  all    0.0.0.0/0  md5" >> /etc/postgresql/${PG_VERSION}/main/pg_hba.conf && \
    chmod +x /scripts/*.sh

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

EXPOSE 5432

USER postgres

VOLUME  ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql/data"]

CMD [ "/scripts/prepare-env-and-run.sh" ]