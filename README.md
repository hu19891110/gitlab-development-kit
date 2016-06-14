# GitLab Development Kit

The GDK runs a GitLab development environment isolated in a directory.
This environment contains GitLab CE and Runner.
This project uses Foreman to run dedicated Postgres and Redis processes for
GitLab development. All data is stored inside the gitlab-development-kit
directory. All connections to supporting services go through Unix domain
sockets to avoid port conflicts.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Design goals](#design-goals)
- [Differences with production](#differences-with-production)
- [GDK Setup](#gdk-setup)
  - [Clone GitLab Development Kit repository](#clone-gitlab-development-kit-repository)
  - [Native installation setup](#native-installation-setup)
    - [Prerequisites for all platforms](#prerequisites-for-all-platforms)
    - [OS X 10.9 (Mavericks), 10.10 (Yosemite), 10.11 (El Capitan)](#os-x-109-mavericks-1010-yosemite-1011-el-capitan)
    - [Ubuntu](#ubuntu)
    - [Arch Linux](#arch-linux)
    - [Debian](#debian)
    - [Fedora](#fedora)
    - [CentOS](#centos)
    - [Other platforms](#other-platforms)
- [Installation](#installation)
  - [GitLab Enterprise Edition](#gitlab-enterprise-edition)
- [Post-installation](#post-installation)
- [Development](#development)
  - [Example](#example)
  - [Running the tests](#running-the-tests)
  - [Simulating Broken Storage Devices](#simulating-broken-storage-devices)
  - [Simulating Slow Filesystems](#simulating-slow-filesystems)
- [Update gitlab and gitlab-shell repositories](#update-gitlab-and-gitlab-shell-repositories)
- [Update configuration files created by gitlab-development-kit](#update-configuration-files-created-by-gitlab-development-kit)
- [PostgreSQL replication](#postgresql-replication)
- [OpenLDAP](#openldap)
- [Elasticsearch](#elasticsearch)
  - [Installation: OS X](#installation-os-x)
  - [Setup](#setup)
- [NFS](#nfs)
  - [Ubuntu / Debian](#ubuntu--debian)
- [HTTPS](#https)
- [SSH](#ssh)
- [OS X, other developer OS's](#os-x-other-developer-oss)
- [Troubleshooting](#troubleshooting)
  - [Rebuilding gems with native extensions](#rebuilding-gems-with-native-extensions)
  - [Error in database migrations when pg_trgm extension is missing](#error-in-database-migrations-when-pg_trgm-extension-is-missing)
  - [Upgrading PostgreSQL](#upgrading-postgresql)
  - [Rails cannot connect to Postgres](#rails-cannot-connect-to-postgres)
  - [undefined symbol: SSLv2_method](#undefined-symbol-sslv2_method)
  - [Fix conflicts in database migrations if you use the same db for CE and EE](#fix-conflicts-in-database-migrations-if-you-use-the-same-db-for-ce-and-ee)
  - ['LoadError: dlopen' when starting Ruby apps](#loaderror-dlopen-when-starting-ruby-apps)
  - ['bundle install' fails due to permission problems](#bundle-install-fails-due-to-permission-problems)
  - ['bundle install' fails while compiling eventmachine gem](#bundle-install-fails-while-compiling-eventmachine-gem)
  - ['Invalid reference name' when creating a new tag](#invalid-reference-name-when-creating-a-new-tag)
  - [Other problems](#other-problems)
- [Executables](#executables)
  - [mount-slow-fs](#mount-slow-fs)
- [License](#license)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Design goals

- Get the user started, do not try to take care of everything
- Run everything as your 'desktop' user on your development machine
- GitLab Development Kit itself does not run `sudo` commands
- It is OK to leave some things to the user (e.g. installing Ruby)

## Differences with production

- gitlab-workhorse does not serve static files
- C compiler needed to run `bundle install` (not needed with Omnibus)
- GitLab can rewrite its program code and configuration data (read-only with
  Omnibus)
- 'Assets' (Javascript/CSS files) are generated on the fly (pre-compiled at
  build time with Omnibus)
- Gems (libraries) for development and functional testing get installed and
  loaded
- No unified configuration management for GitLab and gitlab-shell
  (handled by Omnibus)
- No privilege separation between Ruby, Postgres and Redis
- No easy upgrades
- Need to download and compile new gems ('bundle install') on each upgrade
- etc.

## GDK Setup

The preferred way to use GitLab Development Kit is to install Ruby and
dependencies on your 'native' OS. We strongly recommend the native install
since it is much faster than a virtualized one. Due to heavy IO operations a
virtualized installation will be much slower running the app and the tests.

If you want to use [Vagrant] instead (e.g. need to do development from Windows),
see [the instructions for our (experimental) Vagrant with Virtualbox setup](doc/vagrant.md#vagrant-with-virtualbox).

If you want to use [Vagrant] with [Docker][docker engine] on Linux,
see [the instructions for our (experimental) Vagrant with Docker setup](doc/vagrant.md#vagrant-with-docker).

### Clone GitLab Development Kit repository

Make sure that none of the directories 'above' GitLab Development Kit
contain 'problematic' characters such as ` ` and `(`. For example,
`/home/janedoe/projects` is OK, but `/home/janedoe/my projects` will
cause problems.

```
git clone https://gitlab.com/gitlab-org/gitlab-development-kit.git
cd gitlab-development-kit
```

### Native installation setup

#### Prerequisites for all platforms

If you do not have the dependencies below you will experience strange errors
during installation.

1. A non-root Unix user, this can be your normal user but **DO NOT** run the
   installation as a root user
2. Ruby 2.1 (2.1.8 or newer) installed with a Ruby version manager (RVM, rbenv,
   chruby, etc.), **DO NOT** use the system Ruby
3. Bundler, which you can install with `gem install bundler`

#### OS X 10.9 (Mavericks), 10.10 (Yosemite), 10.11 (El Capitan)

Please read [the prerequisites for all platforms](#prerequisites-for-all-platforms).

```
brew tap homebrew/dupes
brew tap homebrew/versions
brew install git redis postgresql libiconv icu4c pkg-config cmake nodejs go openssl node npm
bundle config build.eventmachine --with-cppflags=-I/usr/local/opt/openssl/include
npm install phantomjs@1.9.8 -g
```

#### Ubuntu

Please read [the prerequisites for all platforms](#prerequisites-for-all-platforms).

```
# Add apt-add-repository helper script
sudo apt-get install software-properties-common python-software-properties
# This PPA contains an up-to-date version of Go
sudo apt-add-repository -y ppa:ubuntu-lxc/lxd-stable
sudo apt-get update
sudo apt-get install git postgresql postgresql-contrib libpq-dev phantomjs redis-server libicu-dev cmake g++ nodejs libkrb5-dev golang ed pkg-config
```

#### Arch Linux

Please read [the prerequisites for all platforms](#prerequisites-for-all-platforms).

```
pacman -S postgresql phantomjs redis postgresql-libs icu nodejs ed cmake openssh git go
```

#### Debian

Please read [the prerequisites for all platforms](#prerequisites-for-all-platforms).

```
sudo apt-get install postgresql postgresql-contrib libpq-dev redis-server libicu-dev cmake g++ nodejs libkrb5-dev ed pkg-config
```

If you are running Debian Stretch or newer you will need to install Go
compiler as well: `sudo apt-get install golang`.

You need to install phantomjs manually:

```
PHANTOM_JS="phantomjs-1.9.8-linux-x86_64"
cd ~
wget https://bitbucket.org/ariya/phantomjs/downloads/$PHANTOM_JS.tar.bz2
tar -xvjf $PHANTOM_JS.tar.bz2
sudo mv $PHANTOM_JS /usr/local/share
sudo ln -s /usr/local/share/$PHANTOM_JS/bin/phantomjs /usr/local/bin
phantomjs --version
```

You may need to install Redis 2.8 or newer manually.

#### Fedora

We assume you are using Fedora >= 22.

```
sudo dnf install postgresql libpqxx-devel postgresql-libs redis libicu-devel nodejs git ed cmake rpm-build gcc-c++ krb5-devel go postgresql-server postgresql-contrib
```

Install `phantomJS` manually, or download it and put in your $PATH. For
instructions, follow the [Debian guide on phantomJS](#debian).

You may need to install Redis 2.8 or newer manually.

#### CentOS

Please read [the prerequisites for all platforms](#prerequisites-for-all-platforms).

This is tested on CentOS 6.5:

```
sudo yum install http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-redhat93-9.3-1.noarch.rpm
sudo yum install http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
sudo yum install postgresql93-server libicu-devel cmake gcc-c++ redis ed fontconfig freetype libfreetype.so.6 libfontconfig.so.1 libstdc++.so.6 golang nodejs

sudo gpg2 --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
sudo curl -sSL https://get.rvm.io | bash -s stable
sudo source /etc/profile.d/rvm.sh
sudo rvm install 2.1
sudo rvm use 2.1
#Ensure your user is in rvm group
sudo usermod -a -G rvm <username>
#add iptables exceptions, or sudo service stop iptables
```

Install `phantomJS` manually, or download it and put in your $PATH. For
instructions, follow the [Debian guide on phantomJS](#debian).

Git 1.7.1-3 is the latest git binary for CentOS 6.5 and GitLab. Spinach tests
will fail due to a higher version requirement by GitLab. You can follow the
instructions found [in the GitLab recipes repository][puias] to install a newer
binary version of Git.

You may need to install Redis 2.8 or newer manually.

#### Other platforms

If you got GDK running an another platform please send a merge request to add
it here.

## Installation

The `Makefile` will clone the repositories, install the Gem bundles and set up
basic configuration files. Pick one:

```
# Clone the official repositories of gitlab and gitlab-shell
make
```

Alternatively, you can clone straight from your forked repositories or GitLab EE.

```
# Clone your own forked repositories
make gitlab_repo=git@gitlab.com:example/gitlab-ce.git gitlab_shell_repo=git@gitlab.com:example/gitlab-shell.git \
  gitlab_ci_repo=git@gitlab.com:example/gitlab-ci.git gitlab_runner_repo=git@gitlab.com:example/gitlab-ci-runner.git
```

In order to more easily contribute changes back from a fork of the GitLab repository, you can run `support/set-gitlab-upstream` after `make` has finished. This creates a remote named `upstream` for [the canonical GitLab CE repository](https://gitlab.com/gitlab-org/gitlab-ce).

This also modifies `make update` (See [Update gitlab and gitlab-shell repositories](Update gitlab and gitlab-shell repositories)) to pull down from the upstream repository instead of your fork, making it easier to keep up-to-date with the project.

If you want to push changes from upstream to your fork, run `make update` and then `git push origin` from the `gitlab` directory.

If you are going to work on Gitlab Geo, you will need [PostgreSQL replication](#postgresql-replication) setup before the "Post-installation" instructions.

### GitLab Enterprise Edition

The recommended way to do development on GitLab Enterprise Edition is
to create a separate GDK directory for it. Below we call that
directory `gdk-ee`. We will configure GDK to start GitLab on port 3001
instead of 3000 so that you can run GDK EE next to CE without port
conflicts.

```
git clone https://gitlab.com/gitlab-org/gitlab-development-kit.git gdk-ee
cd gdk-ee
echo 3001 > port
make gitlab_repo=https://gitlab.com/gitlab-org/gitlab-ee.git
```

Now you can start GitLab EE with `./run` in the `gdk-ee` directory and you
will not have port conflicts with a separate GDK instance for CE that
might still be running.

If you work for GitLab Inc. please see the [developer onboarding
handbook][handbook-ee-license] for how to get an EE license file.

## Post-installation

Start GitLab and all required services:

    ./run

To start only the databases use:

    ./run db

To start only the app (assuming the DBs are already running):

    ./run app

To access GitLab you may now go to http://localhost:3000 in your
browser. The development login credentials are `root` and `5iveL!fe`.

You can override the port used by this GDK with a 'port' file.

    echo 4000 > port

If you want to work on GitLab CI you will need to install [GitLab Runner](https://gitlab.com/gitlab-org/gitlab-ci-multi-runner).

To enable the OpenLDAP server, see the OpenLDAP instructions in this readme.

END Post-installation

Please do not delete the 'END Post-installation' line above. It is used to
print the post-installation message from the `Makefile`.

## Development

When doing development, you will need one shell session (terminal window)
running Postgres and Redis, and one or more other sessions to work on GitLab
itself.

### Example

First start Postgres and Redis.

```
# current directory: gitlab-development-kit
./run
```

Now you can go to http://localhost:3000 in your browser.
The development login credentials are `root` and `5iveL!fe`

### Running the tests

In order to run the test you can use the following commands:
- `rake spinach` to run the spinach suite
- `rake spec` to run the rspec suite
- `rake teaspoon` to run the teaspoon test suite
- `rake gitlab:test` to run all the tests

Note: Both `rake spinach` and `rake spec` takes significant time to pass. 
Instead of running full test suite locally you can save a lot of time by running
a single test or directory related to your changes. After you submit merge request 
CI will run full test suite for you. Green CI status in the merge request means 
full test suite is passed.  

Note: You can't run `rspec .` since this will try to run all the `_spec.rb`
files it can find, also the ones in `/tmp`

To run a single test file you can use:

- `bundle exec rspec spec/controllers/commit_controller_spec.rb` for a rspec test
- `bundle exec spinach features/project/issues/milestones.feature` for a spinach test

To run several tests inside one directory:

- `bundle exec rspec spec/requests/api/` for the rspec tests if you want to test API only
- `bundle exec spinach features/profile/` for the spinach tests if you want to test only profile pages

### Simulating Broken Storage Devices

To test how GitLab behaves when the underlying storage system is not working
you can simply change your local GitLab instance to use an empty directory for
the repositories. To do so edit your `config/gitlab.yml` configuration file so
that the `gitlab_shell.repos_path` option for your environment (e.g.
"development") points to an empty directory.

### Simulating Slow Filesystems

To simulate a slow filesystem you can use the script `bin/mount-flow-fs`. This
script can be used to mount a local directory via SSHFS and slow down access to
the files in this directory. For more information see
[mount-slow-fs](#mount-slow-fs).

## Update gitlab and gitlab-shell repositories

When working on a new feature, always check that your `gitlab` repository is up
to date with the upstream master branch.

In order to fetch the latest code, first make sure that `foreman` for
postgres is runnning (needed for db migration) and then run:

```
make update
```

This will update both `gitlab` and `gitlab-shell` and run any possible
migrations. You can also update them separately by running `make gitlab-update`
and `make gitlab-shell-update` respectively.

If there are changes in the aformentioned local repositories or/and a different
branch than master is checked out, the `make update` commands will stash any
uncommitted changes and change to master branch prior to updating the remote
repositories.

## Update configuration files created by gitlab-development-kit

Sometimes there are changes in gitlab-development-kit that require
you to regenerate configuration files with `make`. You can always
remove an individual file (e.g. `rm Procfile`) and rebuild it by
running `make`. If you want to rebuild _all_ configuration files
created by the Makefile, run `make clean-config all`.

## PostgreSQL replication

For Gitlab Geo, you will need a master/slave database replication defined.
There are a few extra steps to follow:

You must start with a clean postgres setup, (jump to next if you are installing
everything from scratch):

```
rm -rf postgresql
make postgresql
```

Initialize a slave database and setup replication:

```
# terminal window 1:
make postgresql-replication/cluster
foreman start postgresql

# terminal window 2:
make postgresql-replication/role
make postgresql-replication/backup

# go back to terminal window 1 and stop foreman by hitting "CTRL-C"
```

Follow [Post-installation](#post-installation) instructions.

## OpenLDAP

To run the OpenLDAP installation included in the GitLab development kit do the following:

```
vim Procfile # remove the comment on the OpenLDAP line
cd gitlab-openldap
make # will setup the databases
```

in the gitlab repository edit config/gitlab.yml;

```yaml
ldap:
  enabled: true
  servers:
    main:
      label: LDAP
      host: 127.0.0.1
      port: 3890
      uid: 'uid'
      method: 'plain' # "tls" or "ssl" or "plain"
      base: 'dc=example,dc=com'
      user_filter: ''
      group_base: 'ou=groups,dc=example,dc=com'
      admin_group: ''
    # Alternative server, multiple LDAP servers only work with GitLab-EE
    # alt:
    #   label: LDAP-alt
    #   host: 127.0.0.1
    #   port: 3890
    #   uid: 'uid'
    #   method: 'plain' # "tls" or "ssl" or "plain"
    #   base: 'dc=example-alt,dc=com'
    #   user_filter: ''
    #   group_base: 'ou=groups,dc=example-alt,dc=com'
    #   admin_group: ''
```

The second database is optional, and will only work with Gitlab-EE.

The following users are added to the LDAP server:

| uid      | Password | DN                                          | Last     |
| -------- | -------- | -------                                     | ----     |
| john     | password | `uid=john,ou=people,dc=example,dc=com`      |          |
| john0    | password | `uid=john0,ou=people,dc=example,dc=com`     | john9999 |
| mary     | password | `uid=mary,ou=people,dc=example,dc=com`      |          |
| mary0    | password | `uid=mary0,ou=people,dc=example,dc=com`     | mary9999 |
| bob      | password | `uid=bob,ou=people,dc=example-alt,dc=com`   |          |
| alice    | password | `uid=alice,ou=people,dc=example-alt,dc=com` |          |

For testing of GitLab Enterprise Edition the following groups are created.

| cn            | DN                                              | Members | Last          |
| -------       | --------                                        | ------- | ----          |
| group1        | `cn=group1,ou=groups,dc=example,dc=com`         | 2       |               |
| group2        | `cn=group2,ou=groups,dc=example,dc=com`         | 1       |               |
| group-10-0    | `cn=group-10-0,ou=groups,dc=example,dc=com`     | 10      | group-10-1000 |
| group-100-0   | `cn=group-100-0,ou=groups,dc=example,dc=com`    | 100     | group-100-100 |
| group-1000-0  | `cn=group-1000-0,ou=groups,dc=example,dc=com`   | 1,000   | group-1000-10 |
| group-10000-0 | `cn=group-10000-0,ou=groups,dc=example,dc=com`  | 10,000  | group-10000-1 |
| group-a       | `cn=group-a,ou=groups,dc=example-alt,dc=com`    | 2       |               |
| group-b       | `cn=group-b,ou=groups,dc=example-alt,dc=com`    | 1       |               |

## Elasticsearch

### Installation: OS X

1. Install Elasticsearch with [Homebrew]:

    ```sh
    brew install elasticsearch
    ```

1. Install the `delete-by-query` plugin:

    ```sh
    `brew info elasticsearch | awk '/plugin script:/ { print $NF }'` install delete-by-query
    ```

### Setup

1. Edit `gitlab-ee/config/gitlab.yml` to enable Elasticsearch:

    ```yaml
    ## Elasticsearch (EE only)
    # Enable it if you are going to use elasticsearch instead of
    # regular database search
    elasticsearch:
      enabled: true
      # host: localhost
      # port: 9200
    ```

1. Start Elasticsearch by either running `elasticsearch` in a new terminal, or
   by adding it to your `Procfile`:

    ```
    elasticsearch: elasticsearch
    ```

1. Be sure to restart the GDK's `foreman` instance if it's running.

1. Perform a manual update of the Elasticsearch indexes:

    ```sh
    cd gitlab-ee && bundle exec rake gitlab:elastic:index
    ```

## NFS

If you want to experiment with how GitLab behaves over NFS you can use a setup
where your development machine is simultaneously an NFS client and server, with
GitLab reading/writing data as the client.

### Ubuntu / Debian

```
sudo apt-get install -y nfs-kernel-server

# All our NFS exports (data on the 'server') is under /exports/gitlab-data
sudo mkdir -p /exports/gitlab-data/{repositories,gitlab-satellites,.ssh}
# We assume your developer user is git:git
sudo chown git:git /exports/gitlab-data/{repositories,gitlab-satellites,.ssh}

sudo mkdir /etc/exports.d
echo '/exports/gitlab-data 127.0.0.1(rw,sync,no_subtree_check)' | sudo tee /etc/exports.d/gitlab-data.exports
sudo service portmap restart
sudo service nfs-kernel-server restart
sudo exportfs -v 127.0.0.1:/exports/gitlab-data # should show /exports/gitlab-data

# We assume the current directory is the root of your gitlab-development-kit
sudo mkdir -p .ssh repositories gitlab-satellites
sudo mount 127.0.0.1:/exports/gitlab-data/.ssh .ssh
sudo mount 127.0.0.1:/exports/gitlab-data/repositories repositories
sudo mount 127.0.0.1:/exports/gitlab-data/gitlab-satellites gitlab-satellites
# TODO: put the above mounts in /etc/fstab ?
```

## HTTPS

If you want to access GitLab via HTTPS in development you can use
stunnel. The `support/workhorse-stunnel` script requires stunnel 4.0 or
newer. On OS X you can install stunnel with `brew install stunnel`.

First generate a key and certificate for localhost:

```
make localhost.pem
```

On OS X you can add this certificate to the trust store with:
`security add-trusted-cert localhost.crt`.

Next make sure that HTTPS is enabled in gitlab/config/gitlab.yml.

Uncomment the `workhorse-stunnel` line in your Procfile. Now `./run app`
(and `./run`) will start stunnel listening on https://localhost:3443.

## SSH

If you want to work on GitLab's SSH integration then uncomment the
'sshd:' line in your Procfile. Next time you start `run` or `run app`
you will get an unprivileged SSH daemon process running on
localhost:2222, integrated with gitlab-shell.

To change the host/port you need to edit openssh/sshd_config and
gitlab/config/gitlab.yml. If you are not working on GitLab SSH
integration we recommend that you leave the 'sshd:' line in the
Procfile commented out.

## Performance metrics

See [doc/performance_metrics.md](doc/performance_metrics.md).

## OS X, other developer OS's

MR welcome!

## Troubleshooting

### Rebuilding gems with native extensions

There may be times when your local libraries that are used to build some gems'
native extensions are updated (i.e., `libicu`), thus resulting in errors like:

```
rails-background-jobs.1 | /home/user/.rvm/gems/ruby-2.3.0/gems/activesupport-4.2.5.2/lib/active_support/dependencies.rb:274:in 'require': libicudata.so
cannot open shared object file: No such file or directory - /home/user/.rvm/gems/ruby-2.3.0/gems/charlock_holmes-0.7.3/lib/charlock_holmes/charlock_holmes.so (LoadError)
```

In that case, find the offending gem and use `pristine` to rebuild its native
extensions:

```bash
gem pristine charlock_holmes
```

### Error in database migrations when pg_trgm extension is missing

Since GitLab 8.6+ the PostgreSQL extension `pg_trgm` must be installed. If you
are installing GDK for the first time this is handled automatically from the
database schema. In case you are updating your GDK and you experience this
error, make sure you pull the latest changes from the GDK repository and run:

```bash
./support/enable-postgres-extensions
```

### Upgrading PostgreSQL

In case you are hit by `FATAL: database files are incompatible with server`,
you need to upgrade Postgres.

This is what to do when your OS/packaging system decides to install a new minor
version of Postgres:

1. (optional) Downgrade postgres
1. (optional) Make a sql-only GitLab backup
1. Rename/remove the gdk/postgresql/data directory: `mv postgresql/data{,.old}`
1. Run `make`
1. Build pg gem native extensions: `gem pristine pg`
1. (optional) Restore your gitlab backup

If things are working, you may remove the `postgresql/data.old` directory
completely.

### Rails cannot connect to Postgres

- Check if foreman is running in the gitlab-development-kit directory.
- Check for custom Postgres connection settings defined via the environment; we
  assume none such variables are set. Look for them with `set | grep '^PG'`.

### undefined symbol: SSLv2_method

This happens if your local OpenSSL library is updated and your Ruby binary is
built against an older version.

If you are using `rvm`, you should reinstall the Ruby binary. The following
command will fetch Ruby 2.3 and install it from source:

```
rvm reinstall --disable-binary 2.3
```

### Fix conflicts in database migrations if you use the same db for CE and EE

>**Note:**
The recommended way to fix the problem is to rebuild your database and move
your EE development into a new directory.

In case you use the same database for both CE and EE development, sometimes you
can get stuck in a situation when the migration is up in `rake db:migrate:status`,
but in reality the database doesn't have it.

For example, https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/3186
introduced some changes when a few EE migrations were added to CE. If you were
using the same db for CE and EE you would get hit by the following error:

```bash
undefined method `share_with_group_lock' for #<Group
```

This exception happened because the system thinks that such migration was
already run, and thus Rails skipped adding the `share_with_group_lock` field to
the `namespaces` table.

The problem is that you can not run `rake db:migrate:up VERSION=xxx` since the
system thinks the migration is already run. Also, you can not run
`rake db:migrate:redo VERSION=xxx` since it tries to do `down` before `up`,
which fails if column does not exist or can cause data loss if column exists.

A quick solution is to remove the database data and then recreate it:

```bash
rm -rf postgresql/data ; make
```

---

If you don't want to nuke the database, you can perform the migrations manually.
Open a terminal and start the rails console:

```bash
rails console
```

And run manually the migrations:

```
require Rails.root.join("db/migrate/20130711063759_create_project_group_links.rb")
CreateProjectGroupLinks.new.change
require Rails.root.join("db/migrate/20130820102832_add_access_to_project_group_link.rb")
AddAccessToProjectGroupLink.new.change
require Rails.root.join("db/migrate/20150930110012_add_group_share_lock.rb")
AddGroupShareLock.new.change
```

You should now be able to continue your development. You might want to note
that in this case we had 3 migrations happening:

```
db/migrate/20130711063759_create_project_group_links.rb
db/migrate/20130820102832_add_access_to_project_group_link.rb
db/migrate/20150930110012_add_group_share_lock.rb
```

In general it doesn't matter in which order you run them, but in this case
the last two migrations create columns in a table which is created by the first
migration. So, in this example the order is important. Otherwise you would try
to create a column in a non-existent table which would of course fail.

### 'LoadError: dlopen' when starting Ruby apps

This can happen when you try to load a Ruby gem with native extensions that
were linked against a system library that is no longer there. A typical culprit
is Homebrew on OS X, which encourages frequent updates (`brew update && brew
upgrade`) which may break binary compatibility.

```
bundle exec rake db:create dev:setup
rake aborted!
LoadError: dlopen(/Users/janedoe/.rbenv/versions/2.1.2/lib/ruby/gems/2.1.0/extensions/x86_64-darwin-13/2.1.0-static/charlock_holmes-0.6.9.4/charlock_holmes/charlock_holmes.bundle, 9): Library not loaded: /usr/local/opt/icu4c/lib/libicui18n.52.1.dylib
  Referenced from: /Users/janedoe/.rbenv/versions/2.1.2/lib/ruby/gems/2.1.0/extensions/x86_64-darwin-13/2.1.0-static/charlock_holmes-0.6.9.4/charlock_holmes/charlock_holmes.bundle
  Reason: image not found - /Users/janedoe/.rbenv/versions/2.1.2/lib/ruby/gems/2.1.0/extensions/x86_64-darwin-13/2.1.0-static/charlock_holmes-0.6.9.4/charlock_holmes/charlock_holmes.bundle
/Users/janedoe/gitlab-development-kit/gitlab/config/application.rb:6:in `<top (required)>'
/Users/janedoe/gitlab-development-kit/gitlab/Rakefile:5:in `require'
/Users/janedoe/gitlab-development-kit/gitlab/Rakefile:5:in `<top (required)>'
(See full trace by running task with --trace)
```

In the above example, you see that the charlock_holmes gem fails to load
`libicui18n.52.1.dylib`. You can try fixing this by re-installing
charlock_holmes:

```
# in /Users/janedoe/gitlab-development-kit
gem uninstall charlock_holmes
bundle install # should reinstall charlock_holmes
```

### 'bundle install' fails due to permission problems

This can happen if you are using a system-wide Ruby installation. You can
override the Ruby gem install path with `BUNDLE_PATH`:

```
# Install gems in (current directory)/vendor/bundle
make BUNDLE_PATH=$(pwd)/vendor/bundle
```

### 'bundle install' fails while compiling eventmachine gem

On OS X El Capitan, the eventmachine gem compilation might fail with:

```
Gem::Ext::BuildError: ERROR: Failed to build gem native extension.
<snip>
make "DESTDIR=" clean

make "DESTDIR="
compiling binder.cpp
In file included from binder.cpp:20:
./project.h:116:10: fatal error: 'openssl/ssl.h' file not found
#include <openssl/ssl.h>
         ^
1 error generated.
make: *** [binder.o] Error 1

make failed, exit code 2

```

To fix it:

```
bundle config build.eventmachine --with-cppflags=-I/usr/local/opt/openssl/include
```

and then do `bundle install` once again.

### 'Invalid reference name' when creating a new tag

Make sure that `git` is configured correctly on your development
machine (where GDK runs).

```
git checkout -b can-I-commit
git commit --allow-empty -m 'I can commit'
```


### 'gem install nokogiri' fails

Make sure that Xcode Command Line Tools installed on your development machine. For the discussion see this [issue](https://gitlab.com/gitlab-org/gitlab-development-kit/issues/124)

```
brew unlink gcc-4.2      # you might not need this step
gem uninstall nokogiri
xcode-select --install
gem install nokogiri
```


### Other problems

Please open an issue on the [GDK issue tracker](https://gitlab.com/gitlab-org/gitlab-development-kit/issues).

## Executables

A collection of executables can be found in the `bin/` directory. You can use
these executables by adding this directory to your shell's executable path. For
example, when using Bash:

    export PATH="${PATH}:path/to/gdk/bin"

### mount-slow-fs

This script can be used to mount a source directory at a given mount point via
SSHFS and slow down network traffic as a way of replicating a slow NFS. Usage of
this script is as following:

    mount-slow-fs path/to/actual/repositories /path/to/mountpoint

As an example, we'll use the following directories:

* Source directory: ~/Projects/repositories
* Mountpoint: /mnt/repositories

First create the mountpoint and set the correct permissions:

    sudo mkdir /mnt/repositories
    sudo chown $USER /mnt/repositories

Now we can run the script:

    mount-slow-fs ~/Projects/repositories /mnt/repositories

Terminating the script (using ^C) will automatically unmount the repositories
and remove the created traffic shaping rules.

## License

The GitLab Development Kit is distributed under the MIT license,
see the LICENSE file.

[docker engine]: https://docs.docker.com/engine/installation/
[puias]: https://gitlab.com/gitlab-org/gitlab-recipes/tree/master/install/centos#add-puias-computational-repository
[handbook-ee-license]: https://about.gitlab.com/handbook/developer-onboarding#gitlab-enterprise-edition-ee
