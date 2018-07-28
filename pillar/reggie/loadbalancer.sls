{%- from 'reggie/nginx_macros.jinja' import nginx_ssl_config, nginx_proxy_config -%}
{%- from 'reggie/init.sls' import env, minion_id, private_ip, certs_dir -%}

{%- set backends = salt.saltutil.runner('mine.get',
    tgt='*reggie* and G@roles:web and G@env:' ~ env, fun='internal_ip',
    tgt_type='compound').items() %}

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
    https:
      protocol: tcp


haproxy:
  enabled: True
  overwrite: True

  global:
    tune.ssl.default-dh-param: 2048

  listens:
    reggie_http_to_https_redirect:
      mode: http
      bind: '0.0.0.0:80'
      httprequests: 'redirect location https://%[hdr(host),regsub(:80,:443,i)]%[capture.req.uri] code 301'

  frontends:
    reggie_load_balancer:
      mode: http
      bind: '0.0.0.0:443 ssl crt {{ certs_dir }}/{{ minion_id }}.pem'
      redirects: 'scheme https code 301 if !{ ssl_fc }'

      acls:
        {%- for header in ['Location', 'Refresh'] %}
        - 'header_{{ header|lower }}_exists res.hdr({{ header }}) -m found'
        {%- endfor %}

        {%- for path in ['reggie', 'uber', 'profiler', 'stats'] %}
        - 'path_is_{{ path }} path -i /{{ path }}'
        - 'path_starts_with_{{ path }} path_beg -i /{{ path }}/'
        {%- endfor %}

        - 'path_starts_with_static path_beg -i /reggie/static/ /reggie/static_views/ /static/ /static_views/'

      httpresponses:
        {%- for header in ['Location', 'Refresh'] %}
        - 'replace-value {{ header }} https://([^/]*)(?:/reggie)?(.*) https://\1:443\2 if header_{{ header|lower }}_exists'
        {%- endfor %}

      httprequests:
        {%- for path in ['reggie', 'uber'] %}
        - 'redirect location https://%[hdr(host)]%[url,regsub(^/{{ path }}/?,/,i)] code 302 if path_is_{{ path }} OR path_starts_with_{{ path }}'
        {%- endfor %}
        - 'set-path /reggie%[path] if !path_is_profiler !path_starts_with_profiler !path_is_stats !path_starts_with_stats'

      use_backends: 'reggie_http_backend if path_starts_with_static'
      default_backend: 'reggie_https_backend'

  backends:
    reggie_https_backend:
      mode: http
      servers:
        {%- for server, addr in backends %}
        {{ server }}:
          host: {{ addr }}
          port: 443
          extra: 'ssl verify none'
        {%- endfor %}

    reggie_http_backend:
      mode: http
      servers:
        {%- for server, addr in backends %}
        {{ server }}:
          host: {{ addr }}
          port: 80
        {%- endfor %}
