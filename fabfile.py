import time
from fabric.api import run, execute, env

env.use_ssh_config = True
env.hosts = ["congress@congress"]

branch = "congress"
repo = "git://github.com/sunlightlabs/congress.git"

home = "/projects/congress"
shared_path = "%s/shared" % home
version_path = "%s/versions/%s" % (home, time.strftime("%Y%m%d%H%M%S"))
current_path = "%s/current" % home


def checkout():
  run('git clone -q -b %s %s %s' % (branch, repo, version_path))

def links():
  run("ln -s %s/config.yml %s/config/config.yml" % (shared_path, version_path))
  run("ln -s %s/mongoid.yml %s/config/mongoid.yml" % (shared_path, version_path))
  run("ln -s %s/config.ru %s/config.ru" % (shared_path, version_path))
  run("ln -s %s/unicorn.rb %s/unicorn.rb" % (shared_path, version_path))
  run("ln -s %s/data %s/data" % (home, version_path))

def make_current():
  run('rm -f current && ln -s %s current' % version_path)

def start():
  run("cd %s && unicorn -D -l %s/congress.sock -c unicorn.rb" % (current_path, shared_path))

def stop():
  run("kill `cat %s/unicorn.pid`" % shared_path)

def restart():
  run("kill -HUP `cat %s/unicorn.pid`" % shared_path)

# create indexes
# bundle install
# pip install
# set crontab
# disable crontab
# prune releases down to 5


def deploy():
  execute(checkout)
  execute(links)
  execute(make_current)