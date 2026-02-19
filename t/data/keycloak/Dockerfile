FROM keycloak/keycloak:26.5.1-0

RUN mkdir -p /opt/keycloak/data/import
COPY realm.json /opt/keycloak/data/import/realm.json

ENV KC_DB=postgres
ENV KC_DB_URL=jdbc:postgresql://keycloak_db:5432/keycloak
ENV KC_BOOTSTRAP_ADMIN_USERNAME=admin
ENV KC_HTTP_ENABLED=true
ENV KC_HTTP_PORT=9080
ENV KC_HOSTNAME=http://keycloak:9080/auth
ENV KC_HTTP_RELATIVE_PATH=/auth
ENV KC_HOSTNAME_BACKCHANNEL_DYNAMIC=true
ENV KC_PROXY_HEADERS=xforwarded

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start-dev", "--import-realm"]

HEALTHCHECK --interval=10s --timeout=5s --retries=30 --start-period=5s \
  CMD bash -c ":> /dev/tcp/localhost/$KC_HTTP_PORT"
