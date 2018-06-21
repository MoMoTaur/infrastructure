# include:
#   - docker_network_internal


# ============================================================================
# Configure magbot user
# ============================================================================

magbot user:
  user.present:
    - name: magbot


# ============================================================================
# Configure magbot files and plugins
# ============================================================================

{% for subdir in ['ssl', 'data', 'plugins'] %}
{{ salt['pillar.get']('data:path') }}/magbot/{{ subdir }}/:
  file.directory:
    - name: {{ salt['pillar.get']('data:path') }}/magbot/{{ subdir }}
    - makedirs: True
    - user: magbot
    - group: docker
    - dir_mode: 770
    - file_mode: 660
    - recurse:
      - user
      - group
      - mode
{% endfor %}

{{ salt['pillar.get']('data:path') }}/magbot/config.py:
  file.managed:
    - name: {{ salt['pillar.get']('data:path') }}/magbot/config.py
    - source: salt://magbot/config.py
    - template: jinja
    - user: magbot
    - group: docker
    - mode: 660

magbot git latest:
  git.latest:
    - name: https://github.com/magfest/magbot.git
    - target: {{ salt['pillar.get']('data:path') }}/magbot/plugins/magbot

err-profiles git latest:
  git.latest:
    - name: https://github.com/shengis/err-profiles.git
    - target: {{ salt['pillar.get']('data:path') }}/magbot/plugins/err-profiles


# ============================================================================
# Configure magbot logging
# ============================================================================

/var/log/magbot/:
  file.directory:
    - name: /var/log/magbot/
    - makedirs: True
    - user: syslog
    - group: adm

magbot rsyslog conf:
  file.managed:
    - name: /etc/rsyslog.d/magbot.conf
    - contents: |
        if $programname == 'magbot' then /var/log/magbot/magbot.log
        if $programname == 'magbot' then ~
    - listen_in:
      - service: rsyslog

/etc/logrotate.d/magbot:
  file.managed:
    - name: /etc/logrotate.d/magbot
    - contents: |
        /var/log/magbot/magbot.log {
            daily
            missingok
            rotate 52
            compress
            delaycompress
            notifempty
            create 640 syslog adm
            sharedscripts
            postrotate
                invoke-rc.d rsyslog rotate > /dev/null
            endscript
        }


# ============================================================================
# magbot docker container
# ============================================================================

magbot:
  docker_container.running:
    - name: magbot
    - image: magfest/docker-errbot:latest
    - auto_remove: True
    - binds:
      {% for subdir in ['ssl', 'data', 'plugins'] %}
      - {{ salt['pillar.get']('data:path') }}/magbot/{{subdir}}:/srv/{{subdir}}
      {% endfor %}
      - {{ salt['pillar.get']('data:path') }}/magbot/config.py:/app/config.py
    - ports: 3141
    - log_driver: syslog
    - log_opt:
      - tag: magbot
    # - labels:
    #   - traefik.enable=true
    #   - traefik.frontend.rule=Host:{{ salt['pillar.get']('magbot:webserver_domain') }}
    #   - traefik.frontend.entryPoints=http,https
    #   - traefik.port=3141
    #   - traefik.docker.network=docker_network_internal
    # - networks:
    #   - docker_network_internal
    # - require:
    #   - docker_network: docker_network_internal
    - watch_any:
      - file: {{ salt['pillar.get']('data:path') }}/magbot/config.py
      - git: https://github.com/magfest/magbot.git
      - git: https://github.com/shengis/err-profiles.git

# magbot configure webserver:
#   cmd.run:
#     - name: >
#         docker exec -it magbot /app/venv/bin/errbot -c /app/config.py --storage-set
#         "{'configs': {
#         'Webserver': {
#         'PORT': 3141,
#         'HOST': '0.0.0.0',
#         'SSL': {
#         'key': '',
#         'host': '0.0.0.0',
#         'certificate': '',
#         'port': 3142,
#         'enabled': False}}}}"
#     - require:
#       - magbot
