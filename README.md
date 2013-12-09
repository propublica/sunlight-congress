## Docs for the Congress API

We're using Github Pages for our [Sunlight Congress API documentation](http://sunlightlabs.github.io/congress/).

For the last year, we've used [DocumentUp](http://documentup.com/)'s generator API, along with a compilation script. Every change required a re-run of the script, and for DocumentUp's API to be up and running.

The site has now been converted to a Jekyll-based system. In doing so, it revealed a bunch of gaps and inconsistencies in the three primary Markdown parsers that Jekyll supports -- Maruku, Kramdown, and Redcarpet.


### Markdown and Jekyll

Currently, we are waiting for Github Pages to support Jekyll 1.4, so we can use Jekyll 1.4 + Maruku 0.7.0 for the combination of:

* support for fenced code blocks with backticks (GFM-style)
* automatic Pygments-based syntax-specific highlighting of said code blocks
* automatic TOC generation

Maruku [has been EOL-ed](http://benhollis.net/blog/2013/10/20/maruku-is-obsolete/) though, and it would be nice if we could switch to [Redcarpet](https://github.com/vmg/redcarpet) (what Github uses for its own Markdown rendering), or [Kramdown](https://github.com/gettalong/kramdown/) if necessary.

#### Maruku

After a bit of [badgering](https://github.com/mojombo/jekyll/pull/1558#issuecomment-29853283) on my part, [Jekyll 1.4 included](http://jekyllrb.com/news/2013/12/07/jekyll-1-4-0-released/) a lot of (other people's awesome) work to support bumping the included Maruku version to 0.7.0.

Maruku 0.7.0 adds support for fenced code blocks with backticks (instead of just tildes). Unfortunately, Jekyll 1.4 also needs to add support for this option, as it takes a whitelist approach to Maruku options.

Before we can actually deploy this to the live site:

* Jekyll needs to **allow the `fenced_code_blocks` option through**. I'm [working on a patch](https://github.com/konklone/jekyll/commit/14418f74ae743237bede319a8aef2196e48ce569#commitcomment-4805665) for this.
* **Github Pages needs to switch to that patched Jekyll 1.4.**

#### Redcarpet

Before being able to switch to Redcarpet:

* **Automatic generation of TOC** is not supported in Redcarpet 2.x or 3.x, though the building blocks are present. You need to use an alternate renderer, `HTML_TOC`, which gives you the TOC block for you to place in yourself. Adding a special tag that automatically drops the TOC in for you could be done in either Redcarpet or Jekyll, but Redcarpet would make more sense. References: [example helper code](https://github.com/vmg/redcarpet/pull/186#issuecomment-22783188), [my open ticket with redcarpet](https://github.com/vmg/redcarpet/issues/330)

* Support for **Github-style descriptive TOC slugs** when using the `with_toc_data` option will arrive in Jekyll 2.x, when Jekyll drops support for Ruby 1.8.x and can embrace Redcarpet 3.x. Reference: [vmg/redcarpet#186](vmg/redcarpet#186)


#### Kramdown

Before being able to switch to Kramdown:

* Support for **Pygments syntax highlighting** in Kramdown core. @navarroj has created [krampygs](https://github.com/navarroj/krampygs/blob/master/krampygs.rb), a plugin which does this. Kramdown core could offer support for this with a flag, or Jekyll could do it itself, [as it does for Redcarpet](https://github.com/mojombo/jekyll/blob/master/lib/jekyll/converters/markdown/redcarpet_parser.rb#L6-L23).