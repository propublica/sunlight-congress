We're using Github Pages for our [Sunlight Congress API documentation](http://sunlightlabs.github.io/congress/).

For the last year, we've used [DocumentUp](http://documentup.com/)'s generator API, along with a compilation script. Every change required a re-run of the script, and for DocumentUp's API to be up and running.

The site has now been converted to a Jekyll-based system. In doing so, it revealed a bunch of gaps and inconsistencies in the three primary Markdown parsers that Jekyll supports -- Maruku, Kramdown, and Redcarpet.


#### Maruku

After a bit of [badgering](https://github.com/mojombo/jekyll/pull/1558#issuecomment-29853283) on my part, [Jekyll 1.4 included](http://jekyllrb.com/news/2013/12/07/jekyll-1-4-0-released/) a lot of (other people's awesome) work to support bumping the included Maruku version to 0.7.0.

Before being able to switch to Maruku:

* Jekyll needs to **allow the `fenced_code_blocks` option through**. I've [submitted a patch](https://github.com/mojombo/jekyll/pull/1799) for this.
* Maruku has a **bug where newlines wrap fenced code block internals**. I've [submitted a patch](https://github.com/bhollis/maruku/pull/112) that fixes this.
* Maruku only supports internal Pygments highlighting for `{% highlight %}` tags, not fenced code blocks. I need to **figure out what highlighting can be done with fenced code blocks**.
* **Jekyll needs to update** to support the final Maruku version.
* **Github Pages needs to update** to the new version of Jekyll 1.4.x.

#### Redcarpet

Before being able to switch to Redcarpet:

* **Automatic generation of TOC** is not supported in Redcarpet 2.x or 3.x, though the building blocks are present. You need to use an alternate renderer, `HTML_TOC`, which gives you the TOC block for you to place in yourself. Adding a special tag that automatically drops the TOC in for you could be done in either Redcarpet or Jekyll. References: [example helper code](https://github.com/vmg/redcarpet/pull/186#issuecomment-22783188), [my open ticket with redcarpet](https://github.com/vmg/redcarpet/issues/330)

* Bonus: support for **Github-style descriptive TOC slugs** when using the `with_toc_data` option will arrive in Jekyll 2.x, when Jekyll drops support for Ruby 1.8.x and can embrace Redcarpet 3.x. Reference: [vmg/redcarpet#186](vmg/redcarpet#186)

* Bonus: using Rouge for highlighting seems simpler and nicer, and it has a [Redcarpet plugin](https://github.com/jayferd/rouge/blob/master/lib/rouge/plugins/redcarpet.rb).

#### Kramdown

Before being able to switch to Kramdown:

* Support for **Pygments-style syntax highlighting** in Kramdown core. @navarroj has created [krampygs](https://github.com/navarroj/krampygs/blob/master/krampygs.rb), a plugin which does this. Kramdown core could offer support for this with a flag, or Jekyll could do it itself, [as it does for Redcarpet](https://github.com/mojombo/jekyll/blob/master/lib/jekyll/converters/markdown/redcarpet_parser.rb#L6-L23).  Also, Rouge may [add a Kramdown plugin](https://github.com/gettalong/kramdown/pull/68#issuecomment-30182991).