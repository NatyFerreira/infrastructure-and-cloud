FROM alpine
LABEL maintainer="NatyFerreira"

RUN apk update \
    && apk upgrade \
    && apk add figlet

ENTRYPOINT ["figlet"]