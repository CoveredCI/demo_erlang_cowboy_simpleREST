FROM erlang:22-alpine

WORKDIR /opt/app
COPY . $PWD
RUN set -x \
 && rebar3 as prod release
WORKDIR /opt/app/_build/prod/rel/sample

ENV RELX_REPLACE_OS_VARS true
EXPOSE 6773

ENTRYPOINT ["./bin/sample"]
CMD ["foreground"]
