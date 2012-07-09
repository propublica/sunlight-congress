If the index is wiped, run these tasks to get the data back up to speed. 

Where marked with a (*), this task will need to be run manually and will restore data that the cronjob will not.

Append debug=1 to all commands to see extra STDOUT.


votes_house archive=1 year=2012
	(*) repeat for 2011, 2010, 2009
	FILE, MONGO, ES

bills_archive session=112
	(*) repeat for 111
	MONGO

bill_text_archive session=112
	(*) repeat for 111
	ES

regulations_archive year=2012
	(*) repeat for 2011, 2010, 2009
	MONGO

regulations_full_text rearchive_year=2012
	(*) repeat for 2011, 2010, 2009
	FILE, MONGO, ES

bulk_gpo_bills archive=1 year=2012
	(*) repeat for 2011, 2010, 2009
	FILE

house_live archive=True captions=True
house_live archive=True captions=True senate=True
	- currently goes back to 2009 on its own
	MONGO, ES