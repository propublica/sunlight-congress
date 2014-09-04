---
layout: default
---


* placeholder
{:toc}

# Documents

This project covers a wide range of documents including Government Accountability Office (GAO) Reports and Inspectors General Reports. These government oversight documents investigate misconduct and waste as well as access programs for agencies or programs. 

The Inspectors General data is fueled by an amazing volunteer effort that is part of the [@unitedstates](http://theunitedstates.io/) project. These volunteers built scrapers for all 65 US federal inspectors. Check the [inspectors-general](https://github.com/unitedstates/inspectors-general) repo to see the scrapers that are currently running or, learn how to contribute to the project. Feel free to [open a ticket](https://github.com/unitedstates/inspectors-general/issues/new) with any bugs or suggestions.

GAO reports come from the GAO's API


## Methods

All requests require a valid [API key](index.html#parameters/api-key), and use the domain:

{% highlight text %}
https://congress.api.sunlightfoundation.com
{% endhighlight %}

### /documents/search

This provides full-text search for oversight documents. (See the /congressional-documents method for congressional documents)[congressiona_documents.md].

***document_type***
This includes gao_reports 

***document_type_name***
This includes "GAO Reports" and "Inspector General Report"

***posted_at***
Release date of the document

***published_on***
Date the document was published

***title***
Title of the document

***categories***
Kind of document as assigned by the GAO.

***url***
Landing page for the document or link to the document if no landing page.

***source_url***
The document's url.

### Fields for gao_reports:

***gao_id***
Identifier for the document used in the web address on the GAO website.

***report_number***
GAO report number.

***supplement_url***
URL for supplemental information.

***youtube_id***
Youtube id if one is associated with the document.

***links***
Additional links related to the document.

***description***
description of the document

```
gao_report: {
	report_number: "GAO-13-126R",
	description: "What GAO Found...",
	gao_id: "649883",
	supplement_url: null,
	links: null,
	youtube_id: null
},
```
### Fields for ig_report

***inspector_url***
The url to the inspector that created the report. Inspectors are located withing their respective departments.

***pdf***
Meta data from the PDF. Including, modification_date, creation_date, author and page_count.

***published_on***
Document's publication date.

***agency***
Shortened agency name of the agency that produced the report.

***agency_name***
Full agency name.

***type***
General category that identifies it the file is a report, audit, etc.

***url***
The report's URL.

***file_type***
File type of the document, most reports are pdf. 

***title***
The title of the report.

***report_id***
A unique identifier for the report.

***year***
Year of the report.

```
ig_report: {
	topic: "Other",
	inspector_url: "http://www.doi.gov/oig/",
	inspector: "interior",
	pdf: {
		modification_date: "2014-01-30",
		creation_date: "2014-01-30",
		author: "Khadiagala, Lynn",
		page_count: 24
	},
	published_on: "2014-01-30",
	agency: "interior",
	type: "report",
	agency_name: "Department of the Interior",
	url: "http://www.doi.gov/oig/reports/upload/OIGOrganizationalAssessment13Public.pdf",
	file_type: "pdf",
	title: "Office of Inspector General Organizational Assessment 2013",
	report_id: "OIGOrganizationalAssessment13Public",
	year: 2014
},
```

Other fields may appear for particular inspectors. These fields vary by inspector and are experimental.
