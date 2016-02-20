# GitLab Development Kit

The GDK runs a GitLab development environment isolated in a directory.
This environment contains GitLab CE, GitLab EE, GitLab Shell and GitLab
Workhorse.
This project uses [foreman][] to run dedicated Postgres and Redis processes for
GitLab development. All data is stored inside the gitlab-development-kit
directory. All connections to supporting services go through Unix domain
sockets to avoid port conflicts.

* [Design goals](#design-goals)
* [Differences with production](#differences-with-production)
* [Setup](#setup)
  * [Clone Gitlab Development Kit repository](#clone-gitlab-development-kit-repository)
  * [Different installation types](#different-installation-types)
    * [Native installation](#native-installation)
    * [Vagrant with Virtualbox](#vagrant-with-virtualbox)
    * [Vagrant with Docker](#vagrant-with-docker)
* [Installation](#installation)
* [Post-installation](#post-installation)
* [Development](#development)
  * [Example](#example)
  * [Running the tests](#running-the-tests)
* [Update configuration files created by gitlab-development-kit](#update-configuration-files-created-by-gitlab-development-kit)
* [Update gitlab and gitlab-shell repositories](#update-gitlab-and-gitlab-shell-repositories)
* [OpenLDAP](#openldap)
* [NFS](#nfs)
* [Troubleshooting](#troubleshooting)
* [License](#license)

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

## Setup

### Clone GitLab Development Kit repository

```
git clone https://gitlab.com/gitlab-org/gitlab-development-kit.git
cd gitlab-development-kit
```

### Different installation types

The preferred way to use GitLab Development Kit is to install Ruby and dependencies on your 'native' OS.
We strongly recommend the native install since it is much faster than a virtualized one.

If you want to use [Vagrant](https://www.vagrantup.com/) instead (e.g. need to do development from Windows)
please see [the instructions for our (experimental) Vagrant with Virtualbox setup](#vagrant-with-virtualbox).

If you want to use [Vagrant](https://www.vagrantup.com/) with [Docker](https://www.docker.com/) on Linux
please see [the instuctions for our (experimental) Vagrant with Docker setup](#vagrant-with-docker).

#### Native installation

##### Prerequisites for all platforms

If you do not have the dependencies below you will experience strange errors during installation.

1. A non-root unix user, this can be your normal user but **DO NOT** run the installation as a root user
1. Ruby 2.2.4 or newer installed with a Ruby version manager (RVM, rbenv, chruby, etc.), **DO NOT** use the system Ruby
1. Bundler, which you can install with `gem install bundler`

##### OS X 10.9 (Mavericks), 10.10 (Yosemite), 10.11 (El Capitan)

Please read [the prerequisites for all platforms](#prerequisites-for-all-platforms).

```
brew tap homebrew/dupes
brew tap homebrew/versions
brew install git redis postgresql libiconv icu4c pkg-config cmake nodejs go openssl node npm
bundle config build.eventmachine --with-cppflags=-I/usr/local/opt/openssl/include
npm install phantomjs@1.9.8 -g
```

##### Ubuntu

Please read [the prerequisites for all platforms](#prerequisites-for-all-platforms).

```
# This PPA contains an up-to-date version of Go
sudo apt-add-repository -y ppa:ubuntu-lxc/lxd-stable
# This PPA gives us Redis 2.8 or newer
sudo apt-add-repository -y ppa:chris-lea/redis-server
sudo apt-get update
sudo apt-get install git postgresql libpq-dev phantomjs redis-server libicu-dev cmake g++ nodejs libkrb5-dev golang ed pkg-config
```

##### Arch Linux

Please read [the prerequisites for all platforms](#prerequisites-for-all-platforms).

```
sudo pacman -S postgresql phantomjs redis postgresql-libs icu nodejs ed cmake openssh git go
```

##### Debian

Please read [the prerequisites for all platforms](#prerequisites-for-all-platforms).

```
sudo apt-get install postgresql libpq-dev redis-server libicu-dev cmake g++ nodejs libkrb5-dev ed pkg-config
```

If you are running Debian Stretch or newer you will need to install Go compiler as well: `sudo apt-get install golang`

You need to install phantomjs manually

```
PHANTOM_JS="phantomjs-1.9.8-linux-x86_64"
cd ~
wget https://bitbucket.org/ariya/phantomjs/downloads/$PHANTOM_JS.tar.bz2
tar -xvjf $PHANTOM_JS.tar.bz2
sudo mv $PHANTOM_JS /usr/local/share
sudo ln -s /usr/local/share/$PHANTOM_JS/bin/phantomjs /usr/local/bin
phantomjs --version
```


##### Fedora
```
sudo dnf install postgresql libpqxx-devel postgresql-libs redis linicu-devel nodejs git ed cmaker rpm-build lib-pq gcc-c++ krb5-devel
```

Install `phantomJS` manually, or download it and put in your $PATH. For instructions, follow the [Debian guide on phantomJS](#Debian).

##### RedHat

##### CentOS

Please read [the prerequisites for all platforms](#prerequisites-for-all-platforms).

This is tested on CentOS 6.5

```
sudo yum install http://yum.postgresql.org/9.3/redhat/rhel-6-x86_64/pgdg-redhat93-9.3-1.noarch.rpm
sudo yum install http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
sudo yum install postgresql93-server libicu-devel cmake gcc-c++ redis ed fontconfig freetype libfreetype.so.6 libfontconfig.so.1 libstdc++.so.6 golang nodejs

sudo gpg2 --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
sudo curl -sSL https://get.rvm.io | bash -s stable
sudo source /etc/profile.d/rvm.sh
sudo rvm install 2.2
sudo rvm use 2.2
#Ensure your user is in rvm group
sudo usermod -a -G rvm <username>
#add iptables exceptions, or sudo service stop iptables
```

You will want to download the required version of PhantomJS and place the binary on the path.

Git 1.7.1-3 is the latest supported version for CentOS 6.5. Spinach tests will
fail due to a higher version requirement by GitLab.
You can follow the instructions found [here](https://gitlab.com/gitlab-org/gitlab-recipes/tree/master/install/centos#add-puias-computational-repository)
to install a newer binary version of git.

You may need to install Redis 2.8 or newer manually.

##### Other platforms

If you got GDK running an another platform please send a merge request to add it here.

#### Vagrant with Virtualbox

[Vagrant](http://www.vagrantup.com) is a tool for setting up identical development
environments including all dependencies regardless of the host platform you are using.
Vagrant will default to using [VirtualBox](http://www.virtualbox.org), but it has
many plugins for different environments.

Vagrant allows you to develop GitLab without affecting your host machine (but we
recommend developing GitLab on metal if you can).
Vagrant can be very slow since the files are synced between the host OS and GitLab
(testing) accesses a lot of files.
You can improve the speed by keeping all the files on the guest OS but in that case you
should take care to not lose the files if you destroy or update the VM.
To avoid usage of slow VirtualBox shared folders we use NFS here.

##### Install

1. [Disable Hyper-V](http://superuser.com/a/642027/143551) (Windows users) then enable virtualization technology via the BIOS.
2. Install [VirtualBox](https://www.virtualbox.org/wiki/Downloads) & [Vagrant](http://www.vagrantup.com).
3. [Configure NFS for Vagrant](http://docs.vagrantup.com/v2/synced-folders/nfs.html) if you are on Linux.
4. Run `vagrant up --provider=virtualbox` in this directory (from an elevated command prompt if on Windows)
  a. Vagrant will download an OS image, bring it up, and install all the prerequisites.
5. Run `vagrant ssh` to SSH into the box.
6. Continue setup at *[Installation](#installation)* below.
7.  After the installation is done, edit the 'gitlab-workhorse' line in
    your Procfile and change `localhost:3000` to `0.0.0.0:3000`.

##### Development details

* Open development environment by running `vagrant up` & `vagrant ssh` (from an elevated command prompt if on Windows).
* Follow the general [development guidelines](#development) but running the commands in the `vagrant ssh` session.
* Files in the `gitlab`, `gitlab-shell`, `gitlab-ci`, and `gitlab-runner` folders will be synced between the host OS & guest OS so can be edited on either the host (under this folder) or guest OS (under `~/gitlab-development-kit/`).

##### Exit

* When you want to shutdown Vagrant run `exit` from the guest OS and then `vagrant halt`
from the host OS.

##### Vagrant troubleshooting

* On some setups the shared folder will have the wrong user. This is detected
by the Vagrantfile and you should `sudo su - build` to switch to the correct user
in that case.
* If you get a "Timed out while waiting for the machine to boot" message you likely
forgot to [disable Hyper-V](http://superuser.com/a/642027/143551) or enable virtualization technology via the BIOS.
* If you have continious problems starting Vagrant you can uncomment `vb.gui = true`
to view any error messages.
* If you have problems running `support/edit-gitlab.yml` (bash script despite file extension)
 see http://stackoverflow.com/a/5514351/1233435.
* If you have errors with symlinks or Ruby during initialization make sure you ran `vagrant up` from an elevated command prompt (Windows users).

#### Vagrant with Docker

[Vagrant](http://www.vagrantup.com) is a tool for setting up identical development
environments including all dependencies regardless of the host platform you are using.
[Docker](https://www.docker.com/) is one of possible providers of Vagrant.
Docker provider has a big advantage, as it doesn't have a big virtualisation overhead compared
to a Virtualbox and provides the native performance via containering technology.
This docker setup makes sense here only on Linux, as on other OSes like Windows/OSx
you will have to run the entire docker hypervisor in a VM
(which will be almost the same like Vagrant Virtualbox provider).

##### Install
1. Install Docker Engine (e.g. on [Ubuntu](https://docs.docker.com/installation/ubuntulinux/) or [CentOS](https://docs.docker.com/installation/centos/)), don't forget to add your user to the docker group and relogin yourself
2. Run `vagrant up --provider=docker` in this directory. Vagrant will build a docker image and start the container
3. Run `vagrant ssh` to SSH into the container.
5. Continue setup at *[Installation](#installation)* below.
6.  After the installation is done, edit the 'gitlab-workhorse' line in
    your Procfile and change `localhost:3000` to `0.0.0.0:3000`.

See [development details](#development-details) and [exit](#exit) of Vagrant-Virtulabox setup, they apply here too.

## Installation

GitLab development installation is based on a `Makefile` and you can install
both CE and EE versions using the same GDK.

The `Makefile` will clone the repositories, install the Gem bundles and set up
basic configuration files.

### Install both GitLab CE and EE

To clone and setup both GitLab CE and GitLab EE in one go, run:

```
make
```

Alternatively, you can clone straight from your forked repositories or GitLab EE.

```
# Install dependencies
bundle install

# Clone your own forked repositories
make gitlab_ce_repo=git@gitlab.com:example/gitlab-ce.git gitlab_shell_repo=git@gitlab.com:example/gitlab-shell.git
```

### Install either GitLab CE or EE

If you are interested only in the development of either one of GitLab CE or EE,
you can run:

```bash
make ce gitlab-workhorse support-setup
```

Replace `ce` with `ee` to download and install GitLab EE.

If you are going to work on Gitlab Geo, you will need [PostgreSQL replication](#postgresql-replication) setup before the "Post-installation" instructions.

## Post-installation

First run the commands below to install the requirements for the development
kit, then start Redis, PostgreSQL and GitLab-Workhorse with foreman.
In the root of the gitlab-development-kit project:

```bash
bundle install
bundle exec foreman start
```

Next, keep the above command running and from a new terminal session run the
following command to install the required gems, seed the main GitLab database
and setup GitLab:

```bash
cd ce/gitlab && bundle install && bundle exec rake db:create dev:setup
```
## Post-installation

Start GitLab and all required services:

    bundle exec foreman start

To access GitLab you may now go to http://localhost:3000 in your
browser. The development login credentials are `root` and `5iveL!fe`.
>>>>>>> master

Finally, start the main GitLab Rails application while still in the `ce/gitlab/`
subdirectory:

```bash
bundle exec foreman start -p4000
```

This will run Foreman on port 4000. GitLab-workhorse is already running on port
3000, hence to login to GitLab you may now go to http://localhost:3000 in your
browser. The development login credentials are `root` and `5iveL!fe`.

To enable the OpenLDAP server, see the OpenLDAP instructions in this README.

To setup GitLab EE, replace `ce` with `ee` in the commands above. See the
'Switch between GitLab CE and GitLab EE' section in this README for more
information.

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
bundle exec foreman start
```

Next, start a Rails development server for GitLab CE.

```
# terminal window 2
# current directory: gitlab-development-kit/ce/gitlab
bundle exec foreman start -p4000
```

Now you can go to http://localhost:3000 in your browser.
The development login credentials are `root` and `5iveL!fe`

### Running the tests

In order to run the test you can use the following commands:
- `rake spinach` to run the spinach suite
- `rake spec` to run the rspec suite
- `rake teaspoon` to run the teaspoon test suite
- `rake gitlab:test` to run all the tests

Note: You can't run `rspec .` since this will try to run all the `_spec.rb`
files it can find, also the ones in `/tmp`

To run a single test file you can use:

- `bundle exec rspec spec/controllers/commit_controller_spec.rb` for a rspec test
- `bundle exec spinach features/project/issues/milestones.feature` for a spinach test

### Switch between GitLab CE and GitLab EE

In order to be able to run both GitLab CE and EE in one development kit, those
two versions should differentiate somehow. Their data are stored in the `ce/`
and `ee/` directories respectively. Each installation has its own repositories,
gitlab-shell and `.ssh` directory. They talk to one single postgres instance,
each having its own database and they use the same Redis server database.

To run GitLab EE effectively you will need a license key. In order to obtain
one, send an e-mail to `sales@gitlab.com` describing your purpose of
developing on EE.

## Update GitLab, gitlab-shell and gitlab-workhorse

When working on a new feature, always check that your GitLab repository is
up to date with the upstream master branch.

If there are changes in your local repositories or/and a different branch than
master is checked out, the update commands will stash any uncommitted changes
and change to master branch before updating the remote repositories.

The sections below describe how to use the `make` commands to update GitLab. If
you don't want to use the Makefile, the steps you need to manually perform are:

1. Fetch the latest code of GitLab and gitlab-shell
1. Execute `bundle` to install/update any new gems
1. Execute `bundle exec rake db:migrate` to run any database migrations

### Update GitLab CE

If you are developing on GitLab CE, first make sure that `foreman` for
postgres is running (needed for db migration) and then run:

```
make ce/update
```

This will update both GitLab CE and `gitlab-shell` and run any possible
migrations. You can also update them separately by running
`make ce/gitlab-update` and `make ce/gitlab-shell-update` respectively.

### Update GitLab EE

If you are developing on GitLab EE, first make sure that `foreman` for
postgres is running (needed for db migration) and then run:

```bash
make ee/update
```

This will update both GitLab EE and `gitlab-shell` and run any possible
migrations. You can also update them separately by running
`make ee/gitlab-update` and `make ee/gitlab-shell-update` respectively.

### Update gitlab-workhorse

To update gitlab-workhorse, run:

```bash
make gitlab-workhorse-update
```

### Update all

To update GitLab CE, GitLab EE, their gitlab-shells and gitlab workhorse in one
go, run:

```bash
make update
```

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

| uid      | Password | DN                                          |
| -------- | -------- | -------                                     |
| john     | password | `uid=john,ou=people,dc=example,dc=com`      |
| mary     | password | `uid=mary,ou=people,dc=example,dc=com`      |
| bob      | password | `uid=bob,ou=people,dc=example-alt,dc=com`   |
| alice    | password | `uid=alice,ou=people,dc=example-alt,dc=com` |

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

## OS X, other developer OS's

MR welcome!

## Troubleshooting

### Rails cannot connect to Postgres

- Check if foreman is running in the gitlab-development-kit directory.
- Check for custom Postgres connection settings defined via the environment; we
  assume none such variables are set. Look for them with `set | grep '^PG'`.

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

On OS X El Capitan gem eventmachine compilation might fail with:

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

### Other problems

Please open an issue on the [GDK issue tracker](https://gitlab.com/gitlab-org/gitlab-development-kit/issues).

## License

The GitLab Development Kit is distributed under the MIT license,
see the LICENSE file.

[foreman]: https://ddollar.github.io/foreman/
