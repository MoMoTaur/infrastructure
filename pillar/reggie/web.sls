{%- from 'reggie/nginx_macros.jinja' import nginx_ssl_config, nginx_proxy_config -%}
{%- from 'reggie/init.sls' import env, minion_id, private_ip, certs_dir, mounted_data_dir -%}
{%- set glusterfs_ip = salt.saltutil.runner(
    'mine.get',
    tgt='*reggie* and G@roles:files and G@env:' ~ env, fun='internal_ip',
    tgt_type='compound').values()|first -%}

include:
  - reggie


ufw:
  enabled: True

  settings:
    ipv6: False

  sysctl:
    ipv6_autoconf: 0

  applications:
    OpenSSH:
      limit: True
      to_addr: {{ private_ip }}

  services:
    http:
      protocol: tcp
      to_addr: {{ private_ip }}

    https:
      protocol: tcp
      to_addr: {{ private_ip }}


glusterfs:
  client:
    enabled: True
    volumes:
      reggie_volume:
        path: {{ mounted_data_dir }}
        server: {{ glusterfs_ip }}
        user: reggie
        group: reggie


nginx:
  ng:
    certificates_path: {{ certs_dir }}
    dh_param:
      dhparams.pem:
        keysize: 2048
    service:
      enable: True
    server:
      config:
        worker_processes: auto
        worker_rlimit_nofile: 20000

        events:
          worker_connections: 1024

        http:
          client_body_buffer_size: 128k
          client_max_body_size: 20m
          gzip: 'on'
          gzip_min_length: 10240
          gzip_proxied: expired no-cache no-store private auth
          gzip_types: text/plain text/css text/xml text/javascript application/x-javascript application/json application/xml
          reset_timedout_connection: 'on'
          proxy_cache_path: '/var/cache/nginx levels=1:2 keys_zone=one:8m max_size=3000m inactive=600m'
          server_tokens: 'off'
          include:
            - /etc/nginx/mime.types
            - /etc/nginx/conf.d/*.conf
            - /etc/nginx/sites-enabled/*

    servers:
      managed:
        default:
          enabled: False
          config: []

        reggie_site:
          enabled: True
          overwrite: True
          config:
            - server:
              - server_name: localhost
              - listen: '127.0.0.1:443 ssl'
              - listen: '{{ private_ip }}:443 ssl'
              {{ nginx_ssl_config(
                  certs_dir ~ '/' ~ minion_id ~ '.key',
                  certs_dir ~ '/' ~ minion_id ~ '.crt',
                  certs_dir ~ '/dhparams.pem')|indent(14) }}

              {%- for location in ['/preregistration/form'] %}
              - 'location = /reggie{{ location }}':
                - proxy_hide_header: Cache-Control
                {{ nginx_proxy_config(cache='/etc/nginx/reggie_short_term_cache.conf')|indent(16) }}
              {%- endfor %}

              {%- for location in ['/static/', '/static_views/'] %}
              - 'location /reggie{{ location }}':
                {{ nginx_proxy_config(cache='/etc/nginx/reggie_long_term_cache.conf')|indent(16) }}
              {%- endfor %}

              - 'location /':
                {{ nginx_proxy_config()|indent(16) }}

            - server:
              - server_name: localhost
              - listen: '127.0.0.1:80'
              - listen: '{{ private_ip }}:80'

              - access_log: /var/log/nginx/access_static.log
              - error_log: /var/log/nginx/error_static.log

              {%- for location in ['/static/', '/static_views/'] %}
              - 'location /reggie{{ location }}':
                {{ nginx_proxy_config(cache='/etc/nginx/reggie_long_term_cache.conf')|indent(16) }}
              {%- endfor %}

              - 'location /':
                - return: '301 https://$host:443$request_uri'

        reggie_long_term_cache.conf:
          enabled: True
          available_dir: /etc/nginx
          enabled_dir: /etc/nginx
          config:
            - proxy_cache: one
            - proxy_cache_key: $host$request_uri|$request_body
            - proxy_cache_valid: 200 60m
            - proxy_cache_use_stale: error timeout invalid_header updating http_500 http_502 http_503 http_504
            - proxy_cache_bypass: $http_secret_header $arg_nocache
            - add_header: X-Cache-Status $upstream_cache_status

        reggie_short_term_cache.conf:
          enabled: True
          available_dir: /etc/nginx
          enabled_dir: /etc/nginx
          config:
            - proxy_cache: one
            - proxy_cache_key: $host$request_uri
            - proxy_cache_valid: 200 20s
            - proxy_cache_lock: 'on'
            - proxy_cache_lock_age: 40s
            - proxy_cache_lock_timeout: 40s
            - proxy_cache_use_stale: error timeout invalid_header updating http_500 http_502 http_503 http_504
            - proxy_cache_bypass: $http_secret_header $cookie_nocache $arg_nocache $args
            - proxy_no_cache: $http_secret_header $cookie_nocache $arg_nocache $args
            - add_header: X-Cache-Status $upstream_cache_status
