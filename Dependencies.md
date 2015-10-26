Last Updated: October 26th, 2015

Language Dependencies
Ruby 2.1.1
Python 2.7.6


Necessary Languages, Packages & Build Tools

Ruby - comes default with some OS's, but can be installed via RVM - https://rvm.io/rvm/install

From command line `\curl -sSL https://get.rvm.io | bash -s stable --ruby`


Python - comes default with some OS's, can be installed via from here - https://www.python.org/download/releases/2.7.6/

Bundler - ruby package manager
  From command line `gem install bundler`

Brew - http://brew.sh/
  On the command line:
    `ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`
    Poppler
    MongoDB
    Git
      - from command line
          `brew install poppler mongodb git`
          `sudo mkdir -p /data/db`
          `sudo chmod -R 775`

      **Prior to installing Brew you may want to ensure you have Xcode Command Line Toold and Dependecies Installed first. If not you may find this error.



Bundler - from the command Line
  `gem install bundler`

Git - Download here - https://git-scm.com/downloads

Pip - Instructions for downloading here - http://pip.readthedocs.org/en/stable/installing/
  *Alternatively, pip can also be installed from the command line 'sudo easy_install pip' (you may have to use sudo for future commands if using this method)

Virtualenv - `pip install virtualenv`
  - https://virtualenv.pypa.io/en/latest/installation.html

Virtualenvwrapper - `pip install virtualenvwrapper`
    Be sure to complete the all the installation steps for virtualenvwrapper before proceeding
      - http://virtualenvwrapper.readthedocs.org/en/latest/

      If these instructions for Virtualenvwrapper do not work, there is a work around. From the command line:

      mkdir -p ~/bin ~/lib/python2.7 ~/src
      cd ~/src
      ln -s $HOME/lib/python2.7 $HOME/lib/python
      wget http://pypi.python.org/packages/source/v/virtualenvwrapper/virtualenvwrapper-3.6.tar.gz
      tar zxf virtualenvwrapper-3.6.tar.gz
      cd virtualenvwrapper-3.6

      vim ~/.bash_profile
       Type the following:
            export PYTHONPATH=$HOME/lib/python2.7
            export PYTHONPATH=$HOME/lib/python2.7
            source ~/src/virtualenvwrapper-3.6/virtualenvwrapper.sh
            :x [press Enter Key and Open a New Terminal]

      cd ~/src/virtualenvwrapper-3.6
      python2.7 setup.py install --home=$HOME
      source ~/src/virtualenvwrapper-3.6/virutalenvwrapper.sh
      mkvirtualenv env1

      After the last command it should start making an virtual enviornment, see documentation for additional information.

      Sources: https://community.webfaction.com/questions/10316/pip-install-virtualenvwrapper-not-working

      https://docs.webfaction.com/software/python.html#installing-packages-with-setup-py

Clone This Repo

`git clone https://github.com/sunlightlabs/congress`
`cd congress`

See Gem List for Other Ruby Requriements
 To install gems for project
  - `bundle install --local`

From the command line create  a virtual enviornment for congress-api
  `mkvirtualenv congress-api`

Install python requirments
  `pip install -r tasks/requirements.txt`

Setup - Configuration

Copy the example config files:

cp config/config.yml.example config/config.yml
cp config/mongoid.yml.example config/mongoid.yml
cp config.ru.example config.ru


Starting the API

After installing dependencies and MongoDB, and copying the config files, boot the app with:

bundle exec unicorn

In another terminal start mongo
  `mongod`

If you are also running this with the UnitedStates Scrapper (https://github.com/unitedstates/congress-legislators), a project that congress-api gets a fair amount of it's api data from, you will need to setup a symbolic link. This will vary from system to system:
  `ln -s {./data/united/states/congress} {from root of US scrapper/data/}`

Then Run all of the rake tasks, found concatenated in importRakeScripts.md, copy and paste it into the command line.

**This document does not include the setup and configuration of cron(a unix process schedulder) & united-states scrapper (https://github.com/unitedstates/congress-legislators).
