from pymongo import Connection
import pyes
import sys
import os
import traceback
import datetime
import string
import yaml

class Database():

    def __init__(self, task_name, host, name):
        """
        Initialize database connection.
        task_name: of the format "name_of_task", which will get transformed to "NameOfTask" internally.
        host: hostname of mongod
        name: collection name
        """
        self.task_name = string.capwords(task_name, "_").replace("_", "")
        self.connection = Connection(host=host)
        self.db = self.connection[name]

    def report(self, status, message, additional=None):
        """
        Files an unread report for the task runner to read following the conclusion of the task.
        Use the success, warning, and failure methods instead of this method directly.
        """
        
        document = {
          'status': status, 
          'read': False, 
          'message': str(message), 
          'source': self.task_name, 
          'created_at': datetime.datetime.now()
        }
        
        if isinstance(message, Exception):
            exc_type, exc_value, exc_traceback = sys.exc_info()
            backtrace = traceback.format_list(traceback.extract_tb(exc_traceback))
            document['exception'] = {
              'backtrace': backtrace,
              'type': str(exc_type),
              'message': str(exc_value)
            }
        
        if additional:
            document.update(additional)
         
        self.db['reports'].insert(document)
    
    def success(self, message, additional=None):
        self.report("SUCCESS", message, additional)
        
    def warning(self, message, additional=None):
        self.report("WARNING", message, additional)
    
    def note(self, message, additional=None):
        self.report("NOTE", message, additional)
    
    def failure(self, message, additional=None):
        self.report("FAILURE", message, additional)
        
    def get_or_initialize(self, collection, criteria):
        """
        If the document (identified by the critiera dict) exists, update its 
        updated_at timestamp and return it.
        If the document does not exist, start a new one with the attributes in 
        criteria, with both created_at and updated_at timestamps.
        """
        document = None
        documents = self.db[collection].find(criteria)
        
        if documents.count() > 0:
          document = documents[0]
        else:
          document = criteria
          document['created_at'] = datetime.datetime.now()
          
        document['updated_at'] = datetime.datetime.now()
        
        return document
    
    def get_or_create(self, collection, criteria, info):
        """
        Performs a get_or_initialize by the criteria in the given collection,
        and then merges the given info dict into the object and saves it immediately.
        """
        document = self.get_or_initialize(collection, criteria)
        document.update(info)
        self.db[collection].save(document)
    
    def __getitem__(self, collection):
        """
        Passes the collection reference right through to the underlying connection.
        """
        return self.db[collection]


class ElasticSearch():
    
    def __init__(self, host, port, index):
        """
        Initialize ElasticSearch connection.
        host: hostname of elasticsearch daemon
        port: port of elasticsearch daemon
        index: name of elasticsearch index
        """

        self.connection = pyes.ES(server=("http", host, port), timeout=180)
        self.index = index
    
    def save(self, data, typ, o_id):
        return self.connection.index(data, self.index, typ, o_id)

# set global HTTP timeouts to 10 seconds
import socket
socket.setdefaulttimeout(10)

options = yaml.load(open(os.getcwd() + '/config/config.yml', 'r').read())
mongo = yaml.load(open(os.getcwd() + '/config/mongoid.yml', 'r').read())

task_name = sys.argv[1]
db_host = mongo['defaults']['sessions']['default']['hosts'][0]
db_name = mongo['defaults']['sessions']['default']['database']
db = Database(task_name, db_host, db_name)

es_host = options['elastic_search']['host']
es_port = options['elastic_search']['port']
es_index = options['elastic_search']['index']
es = ElasticSearch(es_host, es_port, es_index)


args = sys.argv[2:]
for arg in args:
  key, value = arg.split('=')
  if key and value:
    if value == 'True': value = True
    elif value == 'False': value = False
    options[key.lower()] = value

try:
    sys.path.append("tasks")
    sys.path.append("tasks/%s" % task_name)
    __import__(task_name).run(db, es, options)

except Exception as exception:
    db.failure(exception)