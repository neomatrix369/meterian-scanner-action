FROM meterian/cli:latest-gha

LABEL "repository"="http://github.com/MeterianHQ/meterian-github-action"
LABEL "homepage"="http://github.com/MeterianHQ"
LABEL "maintainer"="Bruno Bossola <bruno@meterian.io>, Mani Sarkar <sadhak001@gmail.com>"


ARG FLUTTER_VERSION=3.22.2
RUN apk add gcompat
RUN wget -q -O /tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
RUN mkdir -p /home/meterian/bin/
RUN tar -xf /tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz -C /home/meterian/bin/
RUN rm /tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz


COPY entrypoint.sh meterian.sh ./

ENTRYPOINT ["/root/entrypoint.sh"]