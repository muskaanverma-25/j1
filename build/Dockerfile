ARG REGISTRY
FROM $REGISTRY/ecr-base_econveyance-dd-ss AS build-image

SHELL [ "/bin/bash", "-c" ]

ARG APP_FOLDER=/econveyance-portal-web-service

WORKDIR $APP_FOLDER

COPY . $APP_FOLDER

RUN amazon-linux-extras install epel -y \
    && yum install -y libxml2-devel libxslt-devel \
    && yum install ImageMagick-devel -y

RUN source /etc/profile.d/rvm.sh \
&& gem update --system 1.8.25 \
&& gem install bundler -v 1.10.6 \
&& bundle install


COPY ./build/docker-entrypoint.sh /usr/bin/docker-entrypoint.sh
RUN chmod +x /usr/bin/docker-entrypoint.sh
COPY ./build/healthcheck.sh /usr/bin/portalws-healthcheck.sh
RUN chmod +x /usr/bin/portalws-healthcheck.sh

EXPOSE $PORT

ENTRYPOINT [ "/bin/bash", "docker-entrypoint.sh" ]