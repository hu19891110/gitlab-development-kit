gitlab_repo = https://gitlab.com/gitlab-org/gitlab-ce.git
gitlab_shell_repo = https://gitlab.com/gitlab-org/gitlab-shell.git
gitlab_workhorse_repo = https://gitlab.com/gitlab-org/gitlab-workhorse.git
gitlab_development_root = $(shell pwd | sed "s/[ \(\)]/\\\&/g")
postgres_bin_dir = $(shell pg_config --bindir)
postgres_replication_user = gitlab_replication
postgres_dir = $(realpath ./postgresql)
postgres_replica_dir = $(realpath ./postgresql-replica)
port = $(shell cat port 2>/dev/null)

all: gitlab-setup gitlab-shell-setup gitlab-workhorse-setup support-setup

# Set up the GitLab Rails app

gitlab-setup: gitlab/.git gitlab-config gitlab/.bundle

gitlab/.git:
	git clone ${gitlab_repo} gitlab

gitlab-config: gitlab/config/gitlab.yml gitlab/config/database.yml gitlab/config/unicorn.rb gitlab/config/resque.yml

gitlab/config/gitlab.yml:
	sed -e "s|/home/git|${gitlab_development_root}|"\
	 gitlab/config/gitlab.yml.example > gitlab/config/gitlab.yml
	port=${port} support/edit-gitlab.yml gitlab/config/gitlab.yml

gitlab/config/database.yml:
	sed "s|/home/git|${gitlab_development_root}|" database.yml.example > gitlab/config/database.yml

gitlab/config/unicorn.rb:
	cp gitlab/config/unicorn.rb.example.development gitlab/config/unicorn.rb
	echo "listen '${gitlab_development_root}/gitlab.socket'" >> $@

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
	  -e "s|^gitlab_url:.*|gitlab_url: http+unix://${shell echo ${gitlab_development_root}/gitlab.socket | sed 's|/|%2F|g'}|"\
	  -e "s|/usr/bin/redis-cli|$(shell which redis-cli)|"\
	  -e "s|^  socket: .*|  socket: ${gitlab_development_root}/redis/redis.socket|"\
	  gitlab-shell/config.yml.example > gitlab-shell/config.yml

gitlab-shell/.bundle:
	cd ${gitlab_development_root}/gitlab-shell && bundle install --without production --jobs 4

# Update gitlab, gitlab-shell and gitlab-workhorse

update: gitlab-update gitlab-shell-update gitlab-workhorse-update

gitlab-update: gitlab/.git/pull
	cd ${gitlab_development_root}/gitlab && \
	bundle install --without mysql production --jobs 4
	@echo ""
	@echo "------------------------------------------------------------"
	@echo "Make sure Postgres is running otherwise db:migrate will fail"
	@echo "------------------------------------------------------------"
	@echo ""
	cd ${gitlab_development_root}/gitlab && \
	bundle exec rake db:migrate db:test:prepare

gitlab-shell-update: gitlab-shell/.git/pull
	cd ${gitlab_development_root}/gitlab-shell && \
	bundle install --without production --jobs 4

gitlab/.git/pull:
	cd ${gitlab_development_root}/gitlab && \
		git checkout -- Gemfile.lock db/schema.rb && \
		git stash && git checkout master && \
		git pull --ff-only

gitlab-shell/.git/pull:
	cd ${gitlab_development_root}/gitlab-shell && \
		git stash && git checkout master && \
		git pull --ff-only

# Set up supporting services

support-setup: .ruby-version foreman Procfile redis postgresql
	@echo ""
	@echo "*********************************************"
	@echo "************** Setup finished! **************"
	@echo "*********************************************"
	@sed -n '/^## Post-installation/,/^END Post-installation/p' README.md
	@echo "*********************************************"

Procfile:
	sed -e "s|/home/git|${gitlab_development_root}|g"\
	  -e "s|postgres |${postgres_bin_dir}/postgres |"\
	  $@.example > $@
	# Listen on external interface if inside a vagrant vm
	if [ -f .vagrant_enabled ] ; \
	then \
		printf ',s/localhost:/0.0.0.0:/g\nwq\n' | ed $@ ; \
	fi;

redis: redis/redis.conf

redis/redis.conf:
	sed "s|/home/git|${gitlab_development_root}|" $@.example > $@

postgresql: postgresql/data

postgresql/data:
	${postgres_bin_dir}/initdb --locale=C -E utf-8 postgresql/data
	support/bootstrap-rails

postgresql-replication/cluster:
	${postgres_bin_dir}/initdb --locale=C -E utf-8 postgresql-replica/data
	cat support/pg_hba.conf.add >> postgresql/data/pg_hba.conf

postgresql-replication/role:
	${postgres_bin_dir}/psql -h ${postgres_dir} -d postgres -c "CREATE ROLE ${postgres_replication_user} WITH REPLICATION LOGIN;"

postgresql-replication/backup:
	psql -h ${postgres_dir} -d postgres -c "select pg_start_backup('base backup for streaming rep')"
	rsync -cva --inplace --exclude="*pg_xlog*" postgresql/data postgresql-replica
	psql -h ${postgres_dir} -d postgres -c "select pg_stop_backup(), current_timestamp"
	./support/recovery.conf ${postgres_dir} > postgresql-replica/data/recovery.conf

.PHONY:	foreman
foreman:
	command -v $@ > /dev/null || gem install $@

.ruby-version:
	ln -s ${gitlab_development_root}/gitlab/.ruby-version $@

localhost.pem: localhost.crt localhost.key
	touch $@
	chmod 600 $@
	cat localhost.key localhost.crt > $@

localhost.crt:	localhost.key

localhost.key:
	openssl req -new -subj "/CN=localhost/" -x509 -days 365 -newkey rsa:2048 -nodes -keyout "localhost.key" -out "localhost.crt"
	chmod 600 $@

gitlab-workhorse-setup: gitlab-workhorse/gitlab-workhorse

gitlab-workhorse-update: gitlab-workhorse/.git/pull
	make

gitlab-workhorse/gitlab-workhorse: gitlab-workhorse/.git
	cd ${gitlab_development_root}/gitlab-workhorse && make

gitlab-workhorse/.git:
	git clone ${gitlab_workhorse_repo} gitlab-workhorse

gitlab-workhorse/.git/pull:
	cd ${gitlab_development_root}/gitlab-workhorse && \
	git pull --ff-only

clean-config:
	rm -f \
	gitlab/config/gitlab.yml \
	gitlab/config/database.yml \
	gitlab/config/unicorn.rb \
	gitlab/config/resque.yml \
	gitlab-shell/config.yml \
	redis/redis.conf \
	Procfile
