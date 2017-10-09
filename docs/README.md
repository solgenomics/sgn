# SGN Documentation
[**View the documentation**](http://solgenomics.github.io/sgn/)

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

#### Images/Screenshots

_For screenshots_: try to make sure that the image is of an unbranded version of the db.

To insert an image, we need to tell Jekyll to generate the relative path to the file like so 
```markdown
![YOUR ALT TEXT]({{'assets/images/YOURIMAGE.png' | relative_url }})
```

#### Links
To insert an link to something outside of the docs, we can use the usual markdown format:
```markdown
[LINK TEXT](http://your.link)
```
If you want to link to a docs page, use this syntax. Note that we put the **path to the file** (from the `docs` directory), **not the rendered HTML page**, after `link`.):
```markdown
[LINK TEXT]({{ site.baseurl }}{% link your_folder/YOUR_FILE.md %})
``` 
If you want to link to a header on a docs page, we can extend the syntax above like so:  
First, we assign the header we are linking to an ID:
```markdown
### I am the header {#your-header-id}
```
then, we add that ID to the link:
```markdown
[LINK TEXT](#your-header-id) <!-- On the same page-->
[LINK TEXT]({{ site.baseurl }}{% link YOUR_FILE.md %}#your-header-id)
```

### Creating New Pages
**Every page should start with this YAML "front-matter" before anything else:**
```markdown
---
title: "YOUR PAGE TITLE HERE"
layout: doc_page
---
```
**To insert a table of contents to a page with the following snippet (INCLUDING the comments [excluding them will cause the TOC to be indexed for search and not be readable by the TOC generator of folder pages.]):**
```markdown
<!-- TOC-START -->
* TOC
{:toc}
<!-- TOC-END -->
```
