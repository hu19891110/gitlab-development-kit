gitlab_repo = https://gitlab.com/gitlab-org/gitlab-ce.git
gitlab_shell_repo = https://gitlab.com/gitlab-org/gitlab-shell.git
gitlab_development_root = $(shell pwd)
postgres_bin_dir = $(shell pg_config --bindir)

all: gitlab-setup gitlab-shell-setup support-setup

# Set up the GitLab Rails app

gitlab-setup: gitlab/.git gitlab-config gitlab/.bundle

gitlab/.git:
	git clone ${gitlab_repo} gitlab

gitlab-config: gitlab/config/gitlab.yml gitlab/config/database.yml gitlab/config/unicorn.rb gitlab/config/resque.yml

gitlab/config/gitlab.yml:
	sed -e "s|/home/git|${gitlab_development_root}|"\
	 -e "s|# user: git|user: $(shell whoami)|"\
	 -e "0,/port: 80/s//port: 3000/"\
	 gitlab/config/gitlab.yml.example > gitlab/config/gitlab.yml

gitlab/config/database.yml:
	sed "s|/home/git|${gitlab_development_root}|" database.yml.example > gitlab/config/database.yml

gitlab/config/unicorn.rb:
	cp gitlab/config/unicorn.rb.example.development gitlab/config/unicorn.rb

gitlab/config/resque.yml:
	sed "s|/home/git|${gitlab_development_root}|" redis/resque.yml.example > $@

gitlab/.bundle:
	cd ${gitlab_development_root}/gitlab && bundle install --without mysql production --jobs 4

# Set up gitlab-shell

gitlab-shell-setup: gitlab-shell/.git gitlab-shell/config.yml gitlab-shell/.bundle

gitlab-shell/.git:
	git clone ${gitlab_shell_repo} gitlab-shell

gitlab-shell/config.yml:
	sed -e "s|/home/git|${gitlab_development_root}|"\
	  -e "s|:8080/|:3000|"\
	  -e "s|/usr/bin/redis-cli|$(shell which redis-cli)|"\
	  -e "s|^  socket: .*|  socket: ${gitlab_development_root}/redis/redis.socket|"\
	  gitlab-shell/config.yml.example > gitlab-shell/config.yml

gitlab-shell/.bundle:
	cd ${gitlab_development_root}/gitlab-shell && bundle install --without production --jobs 4

# Set up supporting services

support-setup: Procfile redis postgresql .bundle
	@echo ""
	@echo "*********************************************"
	@echo "************** Setup finished! **************"
	@echo "*********************************************"
	sed -n '/^### Post-installation/,/^END Post-installation/p' README.md
	@echo "*********************************************"

Procfile:
	sed -e "s|/home/git|${gitlab_development_root}|g"\
	  -e "s|postgres |${postgres_bin_dir}/postgres |"\
	  $@.example > $@

redis: redis/redis.conf

redis/redis.conf:
	sed "s|/home/git|${gitlab_development_root}|" $@.example > $@

postgresql: postgresql/data/PG_VERSION

postgresql/data/PG_VERSION:
	${postgres_bin_dir}/initdb -E utf-8 postgresql/data

.bundle:
	bundle install --jobs 4
