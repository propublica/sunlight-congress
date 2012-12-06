import time
from fabric.api import run, execute, env

environment = "production"

env.use_ssh_config = True
env.hosts = ["congress@congress"]

branch = "congress"
repo = "git://github.com/sunlightlabs/congress.git"

home = "/projects/congress"
shared_path = "%s/congress/shared" % home
version_path = "%s/congress/versions/%s" % (home, time.strftime("%Y%m%d%H%M%S"))
current_path = "%s/congress/current" % home


## can be run only as part of deploy

def checkout():
  run('git clone -q -b %s %s %s' % (branch, repo, version_path))

def links():
  run("ln -s %s/config.yml %s/config/config.yml" % (shared_path, version_path))
  run("ln -s %s/mongoid.yml %s/config/mongoid.yml" % (shared_path, version_path))
  run("ln -s %s/config.ru %s/config.ru" % (shared_path, version_path))
  run("ln -s %s/unicorn.rb %s/unicorn.rb" % (shared_path, version_path))
  run("ln -s %s/data %s/data" % (home, version_path))

def dependencies():
  run("rvm rvmrc trust %s" % version_path)
  run("cd %s && bundle install --local" % version_path)
#  run("workon congress")
#  run("cd %s && pip install -r tasks/requirements.txt" % version_path)

def create_indexes():
  run("cd %s && rake create_indexes" % version_path)

def make_current():
  run('rm -f %s && ln -s %s %s' % (current_path, version_path, current_path))

def prune_releases():
  pass

## can be run on their own

def set_crontab():
  run("cd %s && rake set_crontab environment=%s current_path=%s" % (current_path, environment, current_path))

def disable_crontab():
  run("cd %s && rake disable_crontab" % current_path)

def start():
  run("cd %s && unicorn -D -l %s/congress.sock -c unicorn.rb" % (current_path, shared_path))

def stop():
  run("kill `cat %s/unicorn.pid`" % shared_path)

def restart():
  run("kill -HUP `cat %s/unicorn.pid`" % shared_path)


def deploy():
  execute(checkout)
  execute(links)
  execute(dependencies)
  execute(create_indexes)
  execute(make_current)
  # execute(set_crontab)
  execute(restart)
