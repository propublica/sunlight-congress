Last Updated: October 26th, 2015

## Sunlight Congress API

This is the code that powers the [Sunlight Foundation's Congress API](http://sunlightlabs.github.io/congress/).

### Overview

The Congress API has two parts:

* A light **front end**, written in Ruby using [Sinatra](http://www.sinatrarb.com).
* A **back end** of data scraping and loading tasks. Most are written in Ruby, but Python tasks are also supported.

The **front end** is essentially read-only. Its job is to translate an API call (the query string) into a single database query (usually to MongoDB), wrap the resulting JSON in a bit of pagination metadata, and return it to the user.

Endpoints and behavior are determined by introspecting on the classes defined in `models/`. These classes are also expected to define database indexes where applicable.

The front end tries to maintain as little model-specific logic as possible. There are a couple of exceptions made (like allowing disabling of pagination for `/legislators`) &mdash; but generally, adding a new endpoint is as simple as adding a model class.

The **back end** is a set of tasks (scripts) whose job is to write data to the collections those models refer to. Most data is stored in [MongoDB](http://www.mongodb.org/), but some tasks will store additional data in [Elasticsearch](http://www.elasticsearch.org/), and some tasks may extract citations via a [citation](https://github.com/unitedstates/citation) server.

We currently manage these tasks via  [cron](https://github.com/sunlightlabs/congress/blob/master/config/cron/production.crontab). A small task runner wraps each script in order to ensure any "reports" created along the way get emailed to admins, to catch errors, and to parse command line options.

While the front end and back end are mostly decoupled, many of them do use the definitions in `models/` to save data (via [Mongoid](https://github.com/mongoid/mongoid)) and to manage duplicating "basic" fields about objects onto other objects.

The API **never performs joins** -- if data from one collection is expected to appear as a sub-field on another collection, it should be copied there during data loading.


### Setup - Dependencies


*Ruby 2.1.1
*Python 2.7.6


Installation of Languages, Packages & Build Tools

Ruby - comes default with some OS's, but can be installed via RVM - https://rvm.io/rvm/install

```bash
\curl -sSL https://get.rvm.io | bash -s stable --ruby
```


Python - comes default with some OS's, can be installed via from here - https://www.python.org/download/releases/2.7.6/

Bundler - ruby package manager
  ```bash
  gem install bundler
  ```

Brew - http://brew.sh/
  ```bash
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

  ```

    -Poppler
    -MongoDB
    -Git

      ```bash
          `brew install poppler mongodb git`
          `sudo mkdir -p /data/db`
          `sudo chmod -R 775`
		  ```

      **Prior to installing Brew you may want to ensure you have Xcode Command Line Toold and Dependecies Installed first. If not you may receive an error.



Bundler - from the command Line
	```bash
  	gem install bundler
  	```

Git - Download here - https://git-scm.com/downloads

Pip - Instructions for downloading here - http://pip.readthedocs.org/en/stable/installing/

 **Alternatively, pip can also be installed from the command line 'sudo easy_install pip' (you may have to use sudo for future commands if using this method)

Virtualenv - `pip install virtualenv`
  - https://virtualenv.pypa.io/en/latest/installation.html

Virtualenvwrapper - `pip install virtualenvwrapper`
    Be sure to complete all the installation steps for virtualenvwrapper before proceeding
      - http://virtualenvwrapper.readthedocs.org/en/latest/

      If these instructions for Virtualenvwrapper do not work, there is a work around. From the command line:
```bash
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

      ```

      After the last command it should start making an virtual enviornment, see documentation for additional information.

      Sources:
      	https://community.webfaction.com/questions/10316/pip-install-virtualenvwrapper-not-working
      	https://docs.webfaction.com/software/python.html#installing-packages-with-setup-py

Clone This Repo

```bash
git clone https://github.com/sunlightlabs/congress
cd congress
```

See Gem List for Other Ruby Requriements
 To install gems for the project
  ```bash
  bundle install --local
  ```

From the command line create a virtual enviornment for congress-api
  ```bash
  mkvirtualenv congress-api
  ```

Install python requirments
  ```bash
  pip install -r tasks/requirements.txt
  ```


Copy the example config files:
```bash
cp config/config.yml.example config/config.yml
cp config/mongoid.yml.example config/mongoid.yml
cp config.ru.example config.ru
```

You **don't need to edit these** to get started in development, the defaults should work fine.

In production, you may wish to turn on the API key requirement, and add SMTP server details so that mail can be sent to admins and task owners.

If you work for the Sunlight Foundation, and want it to sync analytics and API keys with HQ, you'll need to update the `services` section with a `shared_secret`.

Read the documentation in [config.yml.example](config/config.yml.example) for a description of each element.


Starting the API

After installing dependencies and MongoDB, and copying the config files, boot the app with:

```bash
bundle exec unicorn
```

In another terminal window start mongo
  ```bash
  mongod
  ```

If you are also running this with the UnitedStates Scrapper (https://github.com/unitedstates/congress-legislators), a project that congress-api gets a fair amount of it's api data from, you will need to setup a symbolic link. This will vary from system to system:
  `ln -s {./data/united/states/congress} {from root of US scrapper/data/}`

Then Run all of the rake tasks, found concatenated in importRakeScripts.md, copy and paste it into the command line.


### Optional - Services

*Optional*. Some tasks that index full text will require [Elasticsearch](http://elasticsearch.org/), a JSONic full-text search engine based on Lucene. Elasticsearch can be installed [via apt](http://www.elasticsearch.org/blog/apt-and-yum-repositories/), or [manually](http://www.elasticsearch.org/overview/elkdownloads/).

*Optional.* If you want citation parsing, you'll need to install [citation](https://github.com/unitedstates/citation), a Node-based citation extractor. After installing Node, you can install it with `[sudo] npm -g install citation`, then run it via `cite-server` on port 3000.

*Optional.* To perform location lookups, you'll need to point the API at an instance of [pentagon](https://github.com/sunlightlabs/pentagon), a boundary service. Sunlight uses an instance loaded with congressional districts and ZCTAs, so that we can look up legislators and districts by either `latitude`/`longitude` or `zip`.

The API should return some enthusiastic JSON at `http://localhost:8080`.

Specify `--port` to use a port other than 8080.

### Running tasks

The API uses `rake` to run data loading tasks, and various other API maintenance tasks.

Every directory in `tasks/` generates an automatic `rake` task, like:

```bash
rake task:hearings_house
```

This will look in `tasks/hearings_house/` for either a `hearings_house.rb` or `hearings_house.py`.

Ruby tasks should define a class named after the file, e.g. `HearingsHouse`, with a class-level `run` method that accepts a hash of options.

Python tasks should just define a `run` method that accepts a dict of options.

Options will be read from the command line using env syntax, for example:

```bash
rake task:hearings_house month=2014-01
```

The options hash will also include an additional `config` key that contains the parsed contents of `config/config.yml`, so that tasks have access to API configuration details.

So `rake task:hearings_house month=2014-01` will execute:

```ruby
HearingsHouse.run({
  month: "2014-01",
  config: {
    # ...parsed config.yml details...
  }
})
```

Task files should define the options they accept at the top of the file, in comments, [like so](https://github.com/sunlightlabs/congress/blob/master/tasks/gao_reports/gao_reports.rb#L6-L11).

### Task Reporting

Tasks can file "reports" as they operate. Reports will be stored in the database, and reports with certain status will be emailed to the admin and any task-specific owners (as configured in `config.yml`).

Since this is MongoDB, any other useful data can simply be dumped onto the report document.

For example, a task might log warnings during its operation, and [send a single warning email](https://github.com/sunlightlabs/congress/blob/master/tasks/gao_reports/gao_reports.rb#L180-L182) at the end:

```
if failures.any?
  Report.failure self, "Failed to process #{failures.size} reports", {failures: failures}
end
```

(In this case, `self` is the class of the task, e.g. `GaoReports`.)

Emails will be sent when filing `failure` or `warning` reports. You can also store `note` reports, and all tasks should file a `success` report at the end if they were successful.

The system will automatically file a `complete` report, with a record of how long a task took - tasks do not need to do this themselves.

Similarly, if an exception is raised during a task, the system will catch it and file (and email) a `failure` report.

Any task that encounters an error or something worth warning about should file a `warning` or `failure` report during operation. After a task completes, the system will examine the reports collection for any "unread" `warning` or `failure` reports, send emails for each one, and mark them as "read".

### Undocumented features

This API has some endpoints and features that are not included in the public documentation, but are used in Sunlight tools.

#### Endpoints

`/regulations` - Material published in [the Federal Register](https://www.federalregister.gov/) since 2009. Currently used in [Scout](https://scout.sunlightfoundation.com).
`/documents` - Reports from the [Government Accountability Office](http://gao.gov), and various [inspectors general](https://github.com/unitedstates/inspectors-general) since 2009. Currently used in [Scout](https://scout.sunlightfoundation.com).
`/videos` - Information on videos from the [House floor](http://houselive.gov/) and [Senate floor](http://floor.senate.gov/), synced through the [Granicus](http://www.granicus.com/) API. Currently used in Sunlight's [Roku apps](http://sunlightfoundation.com/tools/roku/).

#### Citation detection

As bills, regulations, and documents are indexed into the system, they are first run through a [citation extractor](https://github.com/unitedstates/citation) over HTTP.

Extracted citation data is stored locally, in Mongo, in a `citations` collection, using the `Citation` model. Excerpts of surrounding context are also stored then, at index-time.

The API accepts a `citing` parameter, of one or more (pipe-delimited) citation IDs, in the format produced by [unitedstates/citation](https://github.com/unitedstates/citation). Passing `citing` adds a filter (to either Mongo or Elasticsearch-based endpoints) of `citation_ids__all`, which limits results to only documents for which all given citation IDs were detected at index-time.

If a `citing.details` parameter is passed with a value of `true`, then every returned result will trigger a quick database lookup for those associated citations for that document, and citation details (including the surrounding match context) will be added to that document as a `citation` field.

For example, a search for:

```
/bills?citing=usc/5/552&citing.details=true&per_page=1&fields=bill_id
```

Might return something like:

```json
{
  "results": [
    {
      "bill_id": "s2141-113",
      "citations": [
        {
          "type": "usc",
          "match": "section 552(b) of title 5",
          "index": 8624,
          "excerpt": "disclosure pursuant to section 1905 of title 18, United States Code, section 552(b) of title 5, United States Code, or section 301(j) of this Act.",
          "usc": {
            "title": "5",
            "section": "552",
            "subsections": [],
            "id": "usc/5/552",
            "section_id": "usc/5/552"
          }
        }
      ]
    }
  ]
}
```


### License

This project is [licensed](LICENSE) under the [GPL v3](http://www.gnu.org/licenses/gpl-3.0.txt).




**This document does not include the setup and configuration of cron(http://crontab.org/) or united-states scrapper (https://github.com/unitedstates/congress-legislators).
