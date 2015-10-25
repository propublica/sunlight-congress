Last Updated: October 22nd, 2015

Language Dependencies
Ruby 2.1.1
Python 2.7.6


Necessary Languages, Packages & Build Tools

Ruby - comes default with some OS's, can be installed via RVM - https://rvm.io/rvm/install
Python - comes default with some OS's, can be installed via from here - https://www.python.org/download/releases/2.7.6/


Brew - http://brew.sh/
  Poppler
  MongoDB
  Git
    - from command line
        `brew install poppler mongodb`
        `mkdir -p /data/db`

    *Prior to installing Brew you may want to ensure you have Xcode Command Line Toold and Dependecies Installed first. If not you may find this error.



Bundler - from the command Line
  `gem install bundler`

Git - Download here - https://git-scm.com/downloads

Pip - Instructions for downloading here - http://pip.readthedocs.org/en/stable/installing/
  *Alternatively, pip can also be installed from the command line 'sudo easy_install pip' (expect to have to use sudo for commands if using this method)

Virtualenv - `pip install virtualenv`
  - https://virtualenv.pypa.io/en/latest/installation.html

Virtualenvwrapper - `pip install virtualenvwrapper`
    Be sure to complete the all the installation steps for virtualenvwrapper before proceeding
      - http://virtualenvwrapper.readthedocs.org/en/latest/




See Gem List for Other Ruby Requriements
 To install gems for project
  - `bundle install`

Clone This Repo

`git clone https://github.com/sunlightlabs/congress`
