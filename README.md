## Sunlight Congress API

This is the code that powers the [Sunlight Foundation's Congress API](http://sunlightlabs.github.io/congress/).

### Overview



### Setup - Dependencies

Install Ruby dependencies with Bundler:

```bash
bundle install --local
```

If you're going to use any of the Python-based tasks, install [virtualenv](http://www.virtualenv.org/en/latest/) and [virtualenvwrapper](http://virtualenvwrapper.readthedocs.org/en/latest/), make a new virtual environment, and install the Python dependencies:

```bash
mkvirtualenv congress-api
pip install -r tasks/requirements.txt
```

Some tasks use PDF text extraction, which is performed through the [docsplit gem](http://documentcloud.github.com/docsplit/). If you use a task that does this, you will need to install a system dependency, `pdftotext`.

On Linux:

```bash
sudo apt-get install poppler-data
```

Or on OS X:

```bash
brew install poppler
```

### Setup - Configuration

Copy the example config files:

```bash
cp config/config.yml.example config/config.yml
cp config/mongoid.yml.example config/mongoid.yml
cp config.ru.example config.ru`
```

You don't need to edit these to get started in development, the defaults should work fine.

In production, you may wish to turn on the API key requirement, and add SMTP server details so that mail can be sent to admins and task owners.

If you work for the Sunlight Foundation, and want it to sync analytics and API keys with HQ, you'll need to update the `services` section with a `shared_secret`.

Read the documentation in [config.yml.example](config/config.yml.example) for a description of each element.


### Setup - Services

You can get started by just installing MongoDB.

The Congress API depends on [MongoDB](http://www.mongodb.org/), a JSONic document store, for just about everything. MongoDB can be installed via [apt](http://docs.mongodb.org/manual/tutorial/install-mongodb-on-ubuntu/), [homebrew](http://docs.mongodb.org/manual/tutorial/install-mongodb-on-os-x/), or [manually](http://docs.mongodb.org/manual/tutorial/install-mongodb-on-linux/).

Some tasks that index full text will require [Elasticsearch](http://elasticsearch.org/), a JSONic full-text search engine based on Lucene. Elasticsearch can be installed [via apt](http://www.elasticsearch.org/blog/apt-and-yum-repositories/), or [manually](http://www.elasticsearch.org/overview/elkdownloads/).

If you want citation parsing (optional), you'll need to install [citation](https://github.com/unitedstates/citation), a Node-based citation extractor. After installing Node, you can install it with `[sudo] npm -g install citation`, then run it via `cite-server` on port 3000.


### Starting the API

After installing dependencies and MongoDB, and copying the config files, boot the app with:

```
bundle exec unicorn
```

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

### License

This project is [licensed](LICENSE) under the [GPL v3](http://www.gnu.org/licenses/gpl-3.0.txt).