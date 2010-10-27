= Running tasks

Even though they won't appear when you run "rake -T", there is a rake task generated for each task folder in the tasks directory.  Example:

  rake task:house_live

This will assume that by loading tasks/house_live.rb, a class named HouseLive will be defined, and the "run" method will be called on it.  The run method is passed a hash of options.

options[:config] is the contents of config/config.yml in Ruby hash form.
options[:args] is an array of any additional command line parameters, if there are any. (e.g. "rake task:house_live all" would set options[:args] to ["all"])


= Reporting

Tasks can file "reports" by appending new documents to the "reports" table. A report needs to have a status ("SUCCESS", "FAILURE", "WARNING", "COMPLETE"), a source that should be unique to each task ("GetBills", "GetRolls", it doesn't have to be the name of the class, but it should be consistent within a particular task), and a text message saying what happened. Since this is Mongo, any other useful data can simply be dumped onto the report document.

If an exception is raised during a task, it is caught and a FAILURE report is filed. If a task successfully completes, a COMPLETE message is filed (a task should not file one of these on its own), that records an "elapsed_time" field with the number of seconds it took the task to complete.

Any task that encounters an error, or something worth warning the developers about, it should file a report during its operation. After a task completes, the reports table will be examined for any "unread" WARNING or FAILURE reports and an email will be sent to the email addresses specified in config/config.yml.


= Deployment

Staging: 
  cap deploy

Production (backend scraper/parser box):
  cap deploy target=backend

Production (API)
  cap deploy target=api


= Installing dependencies

This project uses the Bundler dependency management system. Gems are packaged in the repository, so no system gems are required. Use "bundle install --local" to install these gems into a local bundle, or use "bundle install [path to desired bundle folder]  --local" to install it to a particular directory. 

Make sure you add the directory you use to the .gitignore file if it's not there already. "vendor/gems" has already been set aside for this purpose, in accordance with Bundler convention.


= Running the development server

This is a Rack app with a config.ru, so running "unicorn" or "rackup" are fine ways to launch the app. Using a Rack-based server that processes the config.ru file will automatically include the gem bundle.  Otherwise, you'll need to do "bundle exec" before the command (such as "bundle exec api.rb" to execute the API directly).