puppet install:
  pkg.installed:
    - name: puppet

fabric install:
  pkg.installed:
    - name: fabric

nodejs-legacy install:
  pkg.installed:
    - name: nodejs-legacy

npm install:
  pkg.installed:
    - name: npm

magbot user:
  user.present:
    - name: magbot

legacy_deploy git latest:
  git.latest:
    - name: https://github.com/magfest/ubersystem-deploy.git
    - target: /srv/legacy_deploy

/srv/legacy_deploy/ chown magbot:
  file.directory:
    - name: /srv/legacy_deploy/
    - user: magbot
    - group: magbot
    - recurse: ['user', 'group']

legacy_deploy fabric_settings.ini:
  file.managed:
    - name: /srv/legacy_deploy/puppet/fabric_settings.ini
    - source: salt://legacy_magbot/fabric_settings.ini
    - template: jinja

legacy_deploy bootstrap_control_server:
  cmd.run:
    - name: fab -H localhost bootstrap_control_server
    - cwd: /srv/legacy_deploy/puppet
    - creates: /srv/legacy_deploy/puppet/hiera/nodes

legacy_magbot git latest:
  git.latest:
    - name: git@github.com:magfest/magbot.git
    - target: /srv/legacy_magbot
    - identity: /root/.ssh/github_magbot.pem

legacy_magbot secret.sh:
  file.managed:
    - name: /srv/legacy_magbot/secret.sh
    - source: salt://legacy_magbot/secret.sh
    - template: jinja

legacy_magbot service conf:
  file.managed:
    - name: /lib/systemd/system/legacy_magbot.service
    - source: salt://legacy_magbot/legacy_magbot.service
    - template: jinja

/srv/legacy_magbot/ chown magbot:
  file.directory:
    - name: /srv/legacy_magbot/
    - user: magbot
    - group: magbot
    - recurse: ['user', 'group']

legacy_magbot service running:
  service.running:
    - name: legacy_magbot
    - watch_any:
      - file: /lib/systemd/system/legacy_magbot.service
      - git: git@github.com:magfest/magbot.git
    - require:
      - pkg: redis-server
