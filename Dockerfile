FROM ruby:3.3-slim
RUN useradd --system --uid 10001 --no-create-home sky
WORKDIR /app
COPY lib ./lib
COPY bin ./bin
RUN chmod 0555 /app/bin/sky_image
USER 10001:10001
WORKDIR /data
ENTRYPOINT ["ruby", "/app/bin/sky_image"]
