If the index is wiped, run these tasks to get the data back up to speed. 

Where marked with a (*), this task will need to be run manually and will restore data that the cronjob will not.

Append debug=1 to all commands to see extra STDOUT.


votes_house archive=1 year=2012
	(*) repeat for 2011, 2010, 2009
	ElasticSearch

votes_senate archive=1 year=2012
	(*) repeat for 2011, 2010, 2009
	ElasticSearch
	
bill_text_archive session=112
	(*) repeat for 111
	ElasticSearch

regulations_full_text rearchive_year=2012
	(*) repeat for 2011, 2010, 2009
	ElasticSearch

documents_gao_reports year=2012 cache=1
	(*) repeat for 2011, 2010, 2009
	ElasticSearch

house_live archive=True captions=True
house_live archive=True captions=True senate=True
	- currently goes back to 2009 on its own
	ElasticSearch

bulk_gpo_bills archive=1 year=2012
	(*) repeat for 2011, 2010, 2009

regulations_archive year=2012
	(*) repeat for 2011, 2010, 2009

bills_thomas session=112
	(*) repeat for 111