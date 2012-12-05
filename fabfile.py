import time
from fabric.api import run, execute, env

env.use_ssh_config = True
env.hosts = ["congress@congress"]

branch = "congress"
repo = "git://github.com/sunlightlabs/congress.git"

home = "/projects/congress"
shared_path = "%s/config" % home
version_path = "%s/versions/%s" % (home, time.strftime("%Y%m%d%H%M%S"))

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

# start
# stop
# restart
# create indexes
# bundle install
# pip install
# set crontab
# disable crontab


def deploy():
  execute(checkout)
  execute(links)
  execute(make_current)