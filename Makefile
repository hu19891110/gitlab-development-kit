gitlab_ce_repo = https://gitlab.com/gitlab-org/gitlab-ce.git
gitlab_ee_repo = https://gitlab.com/gitlab-org/gitlab-ee.git
gitlab_shell_repo = https://gitlab.com/gitlab-org/gitlab-shell.git
gitlab_workhorse_repo = https://gitlab.com/gitlab-org/gitlab-workhorse.git
gitlab_development_root = $(shell pwd)
postgres_bin_dir = $(shell pg_config --bindir)
postgres_replication_user = gitlab_replication
postgres_dir = $(realpath ./postgresql)
postgres_replica_dir = $(realpath ./postgresql-replica)

all: gitlab-ce gitlab-ee gitlab-shell gitlab-workhorse-setup support-setup

#-------------------------------
# Set up the GitLab CE Rails app
#-------------------------------

gitlab-ce: gitlab-ce/.git gitlab-ce/config gitlab-ce/.bundle

gitlab-ce/.git:
	git clone ${gitlab_ce_repo} gitlab-ce

gitlab-ce/config: gitlab-ce/config/gitlab.yml gitlab-ce/config/database.yml gitlab-ce/config/unicorn.rb gitlab-ce/config/resque.yml

gitlab-ce/config/gitlab.yml:
	sed -e "s|/home/git|${gitlab_development_root}|"\
	 gitlab-ce/config/gitlab.yml.example > gitlab-ce/config/gitlab.yml
	support/edit-gitlab.yml gitlab-ce/config/gitlab.yml

gitlab-ce/config/database.yml:
	sed -e "s|/home/git|${gitlab_development_root}|" \
			-e "s|gitlabhq_|gitlabhq_ce_|g" \
			database.yml.example > gitlab-ce/config/database.yml

gitlab-ce/config/unicorn.rb:
	cp gitlab-ce/config/unicorn.rb{.example.development,}
	echo "listen '${gitlab_development_root}/gitlab.socket'" >> $@
	echo "listen '127.0.0.1:8080'" >> $@

gitlab-ce/config/resque.yml:
	sed "s|/home/git|${gitlab_development_root}|" redis/resque.yml.example > $@

gitlab-ce/.bundle:
	cd ${gitlab_development_root}/gitlab-ce && bundle install --without mysql production --jobs 4

#-------------------------------
# Set up the GitLab EE Rails app
#-------------------------------

gitlab-ee: gitlab-ee/.git gitlab-ee/config gitlab-ee/.bundle

gitlab-ee/.git:
	git clone ${gitlab_ee_repo} gitlab-ee

gitlab-ee/config: gitlab-ee/config/gitlab.yml gitlab-ee/config/database.yml gitlab-ee/config/unicorn.rb gitlab-ee/config/resque.yml

gitlab-ee/config/gitlab.yml:
	sed -e "s|/home/git|${gitlab_development_root}|"\
	 gitlab-ee/config/gitlab.yml.example > gitlab-ee/config/gitlab.yml
	support/edit-gitlab.yml gitlab-ee/config/gitlab.yml

gitlab-ee/config/database.yml:
	sed -e "s|/home/git|${gitlab_development_root}|" \
			-e "s|gitlabhq_|gitlabhq_ee_|g" \
			database.yml.example > gitlab-ee/config/database.yml

gitlab-ee/config/unicorn.rb:
	cp gitlab-ee/config/unicorn.rb{.example.development,}
	echo "listen '${gitlab_development_root}/gitlab.socket'" >> $@
	echo "listen '127.0.0.1:8080'" >> $@

gitlab-ee/config/resque.yml:
	sed "s|/home/git|${gitlab_development_root}|" redis/resque.yml.example > $@

gitlab-ee/.bundle:
	cd ${gitlab_development_root}/gitlab-ee && bundle install --without mysql production --jobs 4

# -------------------------
# Setup shared GitLab Shell
# -------------------------
gitlab-shell: gitlab-shell/.git gitlab-shell/config.yml gitlab-shell/.bundle

gitlab-shell/.git:
	git clone ${gitlab_shell_repo} gitlab-shell

gitlab-shell/config.yml:
	sed -e "s|/home/git|${gitlab_development_root}|"\
	  -e "s|^gitlab_url:.*|gitlab_url: http+unix://${shell echo ${gitlab_development_root}/gitlab.socket | sed 's|/|%2F|g'}|"\
	  -e "s|:8080/|:3000|"\
	  -e "s|/usr/bin/redis-cli|$(shell which redis-cli)|"\
	  -e "s|^  socket: .*|  socket: ${gitlab_development_root}/redis/redis.socket|"\
	  gitlab-shell/config.yml.example > gitlab-shell/config.yml

gitlab-shell/.bundle:
	cd ${gitlab_development_root}/gitlab-shell && bundle install --without production --jobs 4

# ------------------------------------------------
# Update gitlab, gitlab-shell and gitlab-workhorse
# ------------------------------------------------

update: ce/update ee/update gitlab-workhorse-update

ce/update: ce/gitlab-update ce/gitlab-shell-update

ee/update: ee/gitlab-update ee/gitlab-shell-update

ce/gitlab-update: gitlab-ce/.git/pull
	cd ${gitlab_development_root}/ce/gitlab && \
	bundle install --without mysql production --jobs 4 && \
	@echo ""
	@echo "------------------------------------------------------------"
	@echo "Make sure Postgres is running otherwise db:migrate will fail"
	@echo "------------------------------------------------------------"
	@echo ""
	bundle exec rake db:migrate

ce/gitlab-shell-update: ce/gitlab-shell/.git/pull
	cd ${gitlab_development_root}/ce/gitlab-shell && \
	bundle install --without production --jobs 4

gitlab-ce/.git/pull:
	cd ${gitlab_development_root}/ce/gitlab && \
		git checkout -- Gemfile.lock db/schema.rb && \
		git stash && git checkout master && \
		git pull --ff-only

ce/gitlab-shell/.git/pull:
	cd ${gitlab_development_root}/ce/gitlab-shell && \
		git stash && git checkout master && \
		git pull --ff-only

ee/gitlab-update: gitlab-ce/.git/pull
	cd ${gitlab_development_root}/ee/gitlab && \
	bundle install --without mysql production --jobs 4 && \
	bundle exec rake db:migrate

ee/gitlab-shell-update: ce/gitlab-shell/.git/pull
	cd ${gitlab_development_root}/ee/gitlab-shell && \
	bundle install --without production --jobs 4

gitlab-ee/.git/pull:
	cd ${gitlab_development_root}/ee/gitlab && \
		git checkout -- Gemfile.lock db/schema.rb && \
		git stash && git checkout master && \
		git pull --ff-only

ee/gitlab-shell/.git/pull:
	cd ${gitlab_development_root}/ee/gitlab-shell && \
		git stash && git checkout master && \
		git pull --ff-only

#---------------------
# Set up gitlab-runner
#---------------------

gitlab-runner-setup: gitlab-runner/.git gitlab-runner/.bundle

gitlab-runner/.git:
	git clone ${gitlab_runner_repo} gitlab-runner

gitlab-runner/.bundle:
	cd ${gitlab_development_root}/gitlab-runner && bundle install --jobs 4

gitlab-runner-clean:
	rm -rf gitlab-runner

gitlab-runner-update: gitlab-runner/.git/pull
	cd ${gitlab_development_root}/gitlab-runner && \
	bundle install

gitlab-runner/.git/pull:
	cd ${gitlab_development_root}/gitlab-runner && git pull --ff-only

# --------------------------
# Set up supporting services
# --------------------------

support-setup: Procfile redis postgresql .bundle
	@echo ""
	@echo "*********************************************"
	@echo "************** Setup finished! **************"
	@echo "*********************************************"
	@sed -n '/^## Post-installation/,/^END Post-installation/p' README.md
	@echo "*********************************************"

Procfile:
	sed -e "s|/home/git|${gitlab_development_root}|g"\
			-e "s|gitlab/public|gitlab-ce/public|"\
	  	-e "s|postgres |${postgres_bin_dir}/postgres |"\
	  $@.example > $@
	# Listen on external interface if inside a vagrant vm
	if [ -f .vagrant_enabled ] ; \
	then \
		printf ',s/localhost:3000/0.0.0.0:3000/g\nwq\n' | ed $@ ; \
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

.bundle:
	bundle install --jobs 4

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
