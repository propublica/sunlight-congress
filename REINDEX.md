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

	rake task:bill_text_archive recite=1 debug=1 session=112 && rake task:bill_text_archive recite=1 debug=1 session=111

	rake task:regulations_full_text debug=1 recite=1 rearchive_year=2012 && rake task:regulations_full_text debug=1 recite=1 rearchive_year=2011 && rake task:regulations_full_text debug=1 recite=1 rearchive_year=2010 && rake task:regulations_full_text debug=1 recite=1 rearchive_year=2009

	rake task:documents_gao_reports cache=1 debug=1 recite=1 year=2012 && rake task:documents_gao_reports cache=1 debug=1 recite=1 year=2011 && rake task:documents_gao_reports cache=1 debug=1 recite=1 year=2010 && rake task:documents_gao_reports cache=1 debug=1 recite=1 year=2009