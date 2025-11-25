# docker/Dockerfile
ARG ODOO_VERSION=17.0
FROM odoo:${ODOO_VERSION}

USER root

# Metadata
ARG BUILD_DATE
ARG VCS_REF
ARG ODOO_VERSION

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${ODOO_VERSION}" \
      org.opencontainers.image.title="Odoo Custom" \
      org.opencontainers.image.description="Custom Odoo ${ODOO_VERSION} with additional modules"

# Встановлення залежностей
RUN apt-get update && apt-get install -y \
    git \
    python3-pip \
    redis-tools \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Копіювання requirements (версія-специфічні залежності)
COPY docker/requirements-common.txt /tmp/requirements-common.txt
COPY docker/ /tmp/docker/
RUN if [ -f /tmp/docker/requirements-${ODOO_VERSION}.txt ]; then \
      cp /tmp/docker/requirements-${ODOO_VERSION}.txt /tmp/requirements-version.txt; \
    else \
      echo "" > /tmp/requirements-version.txt; \
    fi

# Встановлення Python залежностей
RUN pip3 install --no-cache-dir -r /tmp/requirements-common.txt && \
    if [ -s /tmp/requirements-version.txt ]; then \
        pip3 install --no-cache-dir -r /tmp/requirements-version.txt; \
    fi

# Копіювання custom addons
COPY --chown=odoo:odoo custom-addons/ /mnt/extra-addons/

# Копіювання конфігурації
COPY docker/odoo.conf /etc/odoo/

# Скрипт ініціалізації
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Version info
RUN echo "Odoo version: ${ODOO_VERSION}" > /odoo_version.txt

USER odoo

EXPOSE 8069 8072

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]