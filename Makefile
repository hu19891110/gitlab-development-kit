gitlab_ce_repo = https://gitlab.com/gitlab-org/gitlab-ce.git
gitlab_ee_repo = https://gitlab.com/gitlab-org/gitlab-ee.git
gitlab_shell_repo = https://gitlab.com/gitlab-org/gitlab-shell.git
gitlab_runner_repo = https://gitlab.com/gitlab-org/gitlab-ci-runner.git
gitlab_workhorse_repo = https://gitlab.com/gitlab-org/gitlab-workhorse.git
gitlab_development_root = $(shell pwd)
postgres_bin_dir = $(shell pg_config --bindir)

all: ce ee gitlab-workhorse-setup support-setup

#-------------------------------
# Set up the GitLab CE Rails app

ce: ce/gitlab-setup ce/gitlab-shell-setup

ce/gitlab-setup: ce/gitlab/.git ce/gitlab-config ce/gitlab/.bundle

ce/gitlab/.git:
	git clone ${gitlab_ce_repo} ce/gitlab

ce/gitlab-config: ce/gitlab/config/gitlab.yml ce/gitlab/config/database.yml ce/gitlab/config/unicorn.rb ce/gitlab/config/resque.yml

ce/gitlab/config/gitlab.yml:
	sed -e "s|/home/git|${gitlab_development_root}/ce|"\
	 ce/gitlab/config/gitlab.yml.example > ce/gitlab/config/gitlab.yml
	support/edit-gitlab.yml ce/gitlab/config/gitlab.yml

ce/gitlab/config/database.yml:
	sed -e "s|/home/git|${gitlab_development_root}|" \
			-e "s|gitlabhq_|gitlabhq_ce_|g" \
			database.yml.example > ce/gitlab/config/database.yml

ce/gitlab/config/unicorn.rb:
	cp ce/gitlab/config/unicorn.rb{.example.development,}
	echo "listen '${gitlab_development_root}/gitlab.socket'" >> $@
	echo "listen '127.0.0.1:8080'" >> $@

ce/gitlab/config/resque.yml:
	sed "s|/home/git|${gitlab_development_root}|" redis/resque.yml.example > $@

ce/gitlab/.bundle:
	cd ${gitlab_development_root}/ce/gitlab && bundle install --without mysql production --jobs 4

# Set up gitlab-shell

ce/gitlab-shell-setup: ce/gitlab-shell/.git ce/gitlab-shell/config.yml ce/gitlab-shell/.bundle

ce/gitlab-shell/.git:
	git clone ${gitlab_shell_repo} ce/gitlab-shell

ce/gitlab-shell/config.yml:
	sed -e "s|/home/git|${gitlab_development_root}/ce|"\
	  -e "s|:8080/|:3000|"\
	  -e "s|/usr/bin/redis-cli|$(shell which redis-cli)|"\
	  -e "s|^  socket: .*|  socket: ${gitlab_development_root}/redis/redis.socket|"\
	  ce/gitlab-shell/config.yml.example > ce/gitlab-shell/config.yml

ce/gitlab-shell/.bundle:
	cd ${gitlab_development_root}/ce/gitlab-shell && bundle install --without production --jobs 4

#-------------------------------
# Set up the GitLab EE Rails app

ee: ee/gitlab-setup ee/gitlab-shell-setup

ee/gitlab-setup: ee/gitlab/.git ee/gitlab-config ee/gitlab/.bundle

ee/gitlab/.git:
	git clone ${gitlab_ee_repo} ee/gitlab

ee/gitlab-config: ee/gitlab/config/gitlab.yml ee/gitlab/config/database.yml ee/gitlab/config/unicorn.rb ee/gitlab/config/resque.yml

ee/gitlab/config/gitlab.yml:
	sed -e "s|/home/git|${gitlab_development_root}/ee|"\
	 ee/gitlab/config/gitlab.yml.example > ee/gitlab/config/gitlab.yml
	support/edit-gitlab.yml ee/gitlab/config/gitlab.yml

ee/gitlab/config/database.yml:
	sed -e "s|/home/git|${gitlab_development_root}|" \
			-e "s|gitlabhq_|gitlabhq_ee_|g" \
			database.yml.example > ee/gitlab/config/database.yml

ee/gitlab/config/unicorn.rb:
	cp ee/gitlab/config/unicorn.rb{.example.development,}
	echo "listen '${gitlab_development_root}/gitlab.socket'" >> $@
	echo "listen '127.0.0.1:8080'" >> $@

ee/gitlab/config/resque.yml:
	sed "s|/home/git|${gitlab_development_root}|" redis/resque.yml.example > $@

ee/gitlab/.bundle:
	cd ${gitlab_development_root}/ee/gitlab && bundle install --without mysql production --jobs 4

# Set up gitlab-shell

ee/gitlab-shell-setup: ee/gitlab-shell/.git ee/gitlab-shell/config.yml ee/gitlab-shell/.bundle

ee/gitlab-shell/.git:
	git clone ${gitlab_shell_repo} ee/gitlab-shell

ee/gitlab-shell/config.yml:
	sed -e "s|/home/git|${gitlab_development_root}/ee|"\
	  -e "s|:8080/|:3000|"\
	  -e "s|/usr/bin/redis-cli|$(shell which redis-cli)|"\
	  -e "s|^  socket: .*|  socket: ${gitlab_development_root}/redis/redis.socket|"\
	  ee/gitlab-shell/config.yml.example > ee/gitlab-shell/config.yml

ee/gitlab-shell/.bundle:
	cd ${gitlab_development_root}/ee/gitlab-shell && bundle install --without production --jobs 4

#-------------------------------
# Set up gitlab-runner

gitlab-runner-setup: gitlab-runner/.git gitlab-runner/.bundle

gitlab-runner/.git:
	git clone ${gitlab_runner_repo} gitlab-runner

gitlab-runner/.bundle:
	cd ${gitlab_development_root}/gitlab-runner && bundle install --jobs 4

gitlab-runner-clean:
	rm -rf gitlab-runner

# Update gitlab, gitlab-shell and gitlab-runner

update: ce/gitlab-update ce/gitlab-shell-update gitlab-runner-update gitlab-workhorse-update

ce/gitlab-update: gitlab/.git/pull
	cd ${gitlab_development_root}/ce/gitlab && \
	bundle install --without mysql production --jobs 4 && \
	bundle exec rake db:migrate

ce/gitlab-shell-update: ce/gitlab-shell/.git/pull
	cd ${gitlab_development_root}/ce/gitlab-shell && \
	bundle install --without production --jobs 4

gitlab-runner-update: gitlab-runner/.git/pull
	cd ${gitlab_development_root}/gitlab-runner && \
	bundle install

ce/gitlab/.git/pull:
	cd ${gitlab_development_root}/ce/gitlab && \
		git checkout -- Gemfile.lock db/schema.rb && \
		git stash && git checkout master && \
		git pull --ff-only

ce/gitlab-shell/.git/pull:
	cd ${gitlab_development_root}/ce/gitlab-shell && \
		git stash && git checkout master && \
		git pull --ff-only

gitlab-runner/.git/pull:
	cd ${gitlab_development_root}/gitlab-runner && git pull --ff-only

# Set up supporting services

support-setup: Procfile redis postgresql .bundle
	@echo ""
	@echo "*********************************************"
	@echo "************** Setup finished! **************"
	@echo "*********************************************"
	@sed -n '/^## Post-installation/,/^END Post-installation/p' README.md
	@echo "*********************************************"

Procfile:
	sed -e "s|/home/git|${gitlab_development_root}|g"\
			-e "s|gitlab/public|ce/gitlab/public|"\
	  	-e "s|postgres |${postgres_bin_dir}/postgres |"\
	  $@.example > $@

redis: redis/redis.conf

redis/redis.conf:
	sed "s|/home/git|${gitlab_development_root}|" $@.example > $@

postgresql: postgresql/data/PG_VERSION

postgresql/data/PG_VERSION:
	${postgres_bin_dir}/initdb --locale=C -E utf-8 postgresql/data

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
