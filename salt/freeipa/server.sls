{%- set hostname = salt['pillar.get']('freeipa:hostname') -%}
{%- set data_path = salt['pillar.get']('data:path') -%}

include:
  - docker_network_proxy

rng-tools install:
  pkg.installed:
    - name: rng-tools

{{ data_path }}/freeipa/ipa-data/:
  file.directory:
    - makedirs: True

{{ data_path }}/freeipa/ipa-data/etc/httpd/conf.d/ipa-rewrite.conf:
  file.managed:
    - source: salt://freeipa/ipa-rewrite.conf
    - makedirs: True
    - template: jinja

freeipa:
  docker_container.running:
    - name: freeipa
    - image: freeipa/freeipa-server:latest
    - auto_remove: True
    - binds:
      - {{ data_path }}/freeipa/ipa-data:/data:Z
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    - ports: 80,88,88/udp,123/udp,389,443,464,464/udp,636
    - port_bindings:
      - 88:88       # kerberos
      - 88:88/udp   # kerberos
      - 464:464     # kpasswd
      - 464:464/udp # kpasswd
      - 389:389     # ldap
      - 636:636     # ldapssl
    - environment:
      - IPA_SERVER_INSTALL_OPTS: >
          --domain={{ salt['pillar.get']('freeipa:realm')|lower }}
          --realm={{ salt['pillar.get']('freeipa:realm')|upper }}
          --ds-password={{ salt['pillar.get']('freeipa:ds_password') }}
          --admin-password={{ salt['pillar.get']('freeipa:admin_password') }}
          --no-ntp
          --unattended
      - IPA_SERVER_HOSTNAME: {{ hostname }}
    - tmpfs:
      - /run: ''
      - /tmp: ''
    - labels:
      - traefik.enable=true
      - traefik.frontend.rule=Host:{{ hostname }},{{ salt['pillar.get']('freeipa:ui_domain') }}
      - traefik.frontend.entryPoints=http,https
      - traefik.port=80
      - traefik.docker.network=docker_network_internal
    - networks:
      - docker_network_external
      - docker_network_internal
    - watch:
      - file: {{ data_path }}/freeipa/ipa-data/etc/httpd/conf.d/ipa-rewrite.conf
    - require:
      - docker_network: docker_network_external
      - docker_network: docker_network_internal
      - pkg: rng-tools
      - file: {{ data_path }}/freeipa/ipa-data/
      - file: {{ data_path }}/freeipa/ipa-data/etc/httpd/conf.d/ipa-rewrite.conf
    - require_in:
      - sls: freeipa.client

freeipa install:
  cmd.run:
    - name: >
        grep 'The ipa-server-install command was successful' {{ data_path }}/freeipa/ipa-data/var/log/ipaserver-install.log &&
        touch {{ data_path }}/freeipa/ipa-data/var/log/ipaserver-install-complete
    - creates: {{ data_path }}/freeipa/ipa-data/var/log/ipaserver-install-complete
    - require:
      - freeipa

freeipa default login shell:
  file.line:
    - name: {{ data_path }}/freeipa/ipa-data/etc/sssd/sssd.conf
    - content: override_shell = /bin/bash
    - after: [domain/magfest.org]
    - mode: ensure
    - require:
        - freeipa install
