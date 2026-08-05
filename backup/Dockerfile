FROM mariadb:10.6

RUN apt-get update \
    && apt-get install -y cron \
    && rm -rf /var/lib/apt/lists/*

CMD ["cron", "-f"]
