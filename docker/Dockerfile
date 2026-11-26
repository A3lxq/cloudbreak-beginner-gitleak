FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        nginx-light \
        git \
        openssh-server \
        sudo \
        python3 \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/web /opt/templates

COPY web/ /opt/web/
COPY templates/ /opt/templates/
COPY nginx-default.conf /etc/nginx/sites-available/default
COPY generate_flags.py /opt/generate_flags.py
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

EXPOSE 22 80

ENTRYPOINT ["/opt/entrypoint.sh"]
