If database is really new:

	rake create_indexes

Non-ES:

	rake task:bills debug=1 congress=112 && rake task:bills debug=1 congress=112

	rake task:districts debug=1 cache=1 per_page=34000

ElasticSearch:

	rake task:bills_text debug=1 congress=112 && rake task:bills_text debug=1 congress=111

	rake task:regulations cache=1 debug=1 year=2012 && rake task:regulations debug=1 cache=1 year=2011 && rake task:regulations debug=1 cache=1 year=2010 && rake task:regulations debug=1 year=2009 cache=1

	rake task:gao_reports cache=1 debug=1 year=2012 && rake task:gao_reports cache=1 debug=1 year=2011 && rake task:gao_reports cache=1 debug=1 year=2010 && rake task:gao_reports cache=1 debug=1 year=2009

	rake task:votes_house year=2012 cache=1 debug=1 && rake task:votes_house year=2011 cache=1 debug=1 && rake task:votes_house year=2010 cache=1 debug=1 && rake task:votes_house year=2009 debug=1 cache=1

	rake task:votes_senate year=2012 cache=1 debug=1 && rake task:votes_senate year=2011 cache=1 debug=1 && rake task:votes_senate year=2010 cache=1 debug=1 && rake task:votes_senate year=2009 debug=1 cache=1

	rake task:videos archive=True captions=True && rake task:videos archive=True captions=True senate=True