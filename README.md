# Installing dependencies

The docsplit gem (PDF text extraction) requires some [system dependencies](http://documentcloud.github.com/docsplit/).

# Running tasks

There is a rake task generated for each task folder in the tasks directory.  Example:

  rake task:house_live

This will assume that by loading `tasks/house_live/house_live.rb`, a class named HouseLive will be defined, and the "run" method will be called on it.  The run method is passed a hash of options.

options[:config] is the contents of config/config.yml in the form of a Ruby hash. Command line parameters in the form of "key=value" get put into the options hash in the form of options[:key] => value.


# Reporting

Tasks can file "reports" by appending new documents to the "reports" table. A report needs to have a status ("SUCCESS", "FAILURE", "WARNING", "NOTE"), a source name that should be unique to each task, and text describing what happened. Since this is Mongo, any other useful data can simply be dumped onto the report document.

WARNING reports will cause an email to be sent, whereas NOTE reports will not.

If an exception is raised during a task, it is caught and a FAILURE report is filed. If a task successfully completes, a COMPLETE message is filed (a task should not file one of these on its own), that records an "elapsed_time" field with the number of seconds it took the task to complete.

Any task that encounters an error, or something worth warning the developers about, it should file a report during its operation. After a task completes, the reports table will be examined for any "unread" WARNING or FAILURE reports and an email will be sent to the email addresses specified in config/config.yml.


# Deployment

For the Ruby side of this project, it uses the Bundler dependency management system. Gems are packaged in the repository, so no system gems are required. Use "bundle install --local" to install these gems into a local bundle, or use "bundle install [path to desired bundle folder]  --local" to install it to a particular directory. 

Make sure you add the directory you use to the .gitignore file if it's not there already. "vendor/gems" has already been set aside for this purpose, in accordance with Bundler convention.

For the Oython tasks, Python 2.7 or higher is required. Tasks have not been tested for Python 3 compatibility. To install third party Python dependencies, use pip and the requirements file: "pip install -r requirements.txt"


= Running the development server

This is a Rack app with a config.ru, so running "unicorn" or "rackup" are fine ways to launch the app. Using a Rack-based server that processes the config.ru file will automatically include the gem bundle.  Otherwise, you'll need to do "bundle exec" before the command (such as "bundle exec api.rb" to execute the API directly).