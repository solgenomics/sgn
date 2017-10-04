# SGN Documentation
[**View the documentation**]()

### Syntax and Use
The documentation is written in [kramdown-flavored](https://kramdown.gettalong.org/) markdown. It also takes advantage of the [Liquid](https://shopify.github.io/liquid/) templating system and the built-in variable in [Jekyll](https://jekyllrb.com), the static site generator that GitHub pages uses.

This folder (`docs/`) can be used to build the site either via GitHUb pages or via a local Jekyll installation.

### Guidelines for adding to the documentation

#### Headers
```markdown
Header 1 OR
===========

# Header 1

Header 2 OR
-----------

## Header 2

### Header 3

#### Header 4

##### Header 5

###### Header 6
```
You probably shouldnt use h1 headers, as the title of the page is always displayed as an h1, and using them elsewhere could be visualy confusing. 

**DONT USE BOLD INSTEAD OF HEADERS** (except in tables). Doing so makes generating a TOC impossible (and also visually looks off.)

#### Horizontal Rules (Section Seperators) 

In kramdown, a horizontal rule must be preceeded and followed by a blank line:
```markdown
I am above the hr

-----------------

I am below the hr
```

#### Images

To insert an image, we need to tell Jekyll to generate the relative path to the file like so 
```markdown
![YOUR ALT TEXT]({{'assets/images/YOURIMAGE.png' | relative_url }})
```

#### Links
To insert an link, we can use the usual markdown format:
```markdown
[YOUR LINK TEXT](http://your.link)
```
If you want to link to a header on a specific page, read this [documentation](https://kramdown.gettalong.org/syntax.html#specifying-a-header-id).

### Creating New Pages
**Every page should start with this YAML "front-matter" before anything else:**
```markdown
---
title: "YOUR PAGE TITLE HERE"
layout: doc_page
---
```
**To insert a table of contents to a page with the following snippet:**
```markdown
<input type="hidden" toc="start" />
* TOC
{:toc}
<input type="hidden" toc="end" />
```
