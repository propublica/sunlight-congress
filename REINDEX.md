If the index is wiped, run these tasks to get the data back up to speed. 

Where marked with a (*), this task will need to be run manually and will restore data that the cronjob will not.

Append debug=1 to all commands to see extra STDOUT.


votes_house year=2012
	(*) repeat for 2011, 2010, 2009

votes_senate year=2012
	(*) repeat for 2011, 2010, 2009
	
bill_text_archive session=112
	(*) repeat for 111

regulations_archive year=2012 cache=1
	(*) repeat for 2011, 2010, 2009

documents_gao_reports year=2012 cache=1
	(*) repeat for 2011, 2010, 2009
	ElasticSearch

house_live archive=True captions=True
house_live archive=True captions=True senate=True
	- currently goes back to 2009 on its own
	ElasticSearch

==============================

	rake task:bill_text_archive debug=1 session=112 batch_size=10 && rake task:bill_text_archive debug=1 session=111 batch_size=10

	rake task:regulations_archive cache=1 debug=1 year=2012 batch_size=10 && rake task:regulations_archive debug=1 cache=1 year=2011 batch_size=10 && rake task:regulations_archive debug=1 cache=1 year=2010 batch_size=10 && rake task:regulations_archive debug=1 year=2009 cache=1 batch_size=10

	rake task:documents_gao_reports cache=1 debug=1 year=2012 && rake task:documents_gao_reports cache=1 debug=1 year=2011 && rake task:documents_gao_reports cache=1 debug=1 year=2010 && rake task:documents_gao_reports cache=1 debug=1 year=2009

	rake task:votes_house year=2012 debug=1 && rake task:votes_house year=2011 debug=1 && rake task:votes_house year=2010 debug=1 && rake task:votes_house year=2009 debug=1

	rake task:votes_senate year=2012 debug=1 && rake task:votes_senate year=2011 debug=1 && rake task:votes_senate year=2010 debug=1 && rake task:votes_senate year=2009 debug=1