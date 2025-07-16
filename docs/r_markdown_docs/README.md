## SGN Documentation
[View the documentation](http://solgenomics.github.io/sgn/)

### Syntax and Use

This folder `docs/` can be used to build the site through R package - bookdown. More about bookdown here.  

https://bookdown.org/
https://bookdown.org/yihui/bookdown/

The entire page along with the source files in r-markdown format are in the folder 
`/docs/r_markdown_docs`

### Tools. 
The best way to work with the documentation is to 
1. Install the free R Studio with on your local machine with the sgn repository.
2. Set the working directory environment variable to the path from our documentation R command `setwd("{path_on_local_machine}/sgn/docs/r_markdown_docs")` we can check current working directory by `getwd()`.
3. Install R package “bookdown”, "rmarkdown" and "pandoc".

###   How to work with documentation
1. **Introduction**
This section provides an overview of managing R Markdown documentation using Bookdown and outlines the purpose of this technical manual.
2. **Defining the Document Structure** in `_bookdown.yml` file.
Files: Structure of the document is stored in `_bookdown.yml` file. 
`Rmd_files` variable in `_bookdown.yml` is a list of documents used to build a documentation in a given order. If we want to add a new file to documentation - it must be added to the Rmd_files list and a new file must be created in `r_markdown_docs` folder with .Rmd extension.
Setting the Order of Chapters/Sections: Order of chapters is an order of files in `Rmd_files` list.   
3. **Adding New Chapters/Sections**
Creating New R Markdown Files: to create a new sectiono or chapter - just create a `<filename>.Rmd` file in `/docs/r_markdown_docs` folder.
Updating the Rmd Files List: Once you create a file and want to add it to official documentation update `_bookdown.yml` -> `Rmd_files` with new additions.
4. **Building Your Documentation**
Rendering the Documentation: Best way to render document is to use knit icon ( command ) in `RStudio` when open `Index.Rmd`
Alternative to preview html gitbook format and pdf is to use command in R:
`bookdown::render_book("index.Rmd", "bookdown::pdf_book")`
`bookdown::render_book("index.Rmd", "bookdown::gitbook")`
Previewing the Documentation: Best option is RStudio - with `knit` command we have also a live local server for gitbook html documents. 
5. **Deployment and Sharing**
Publishing Your Documentation: 
    1. Once changes in documentation are done. Please save all `.Rmd` files in the `r_markdown_docs` folder and check `_bookdown.yml` file if the structure is correct.  
    2. Build and check in `RStudio` or any other live server if changes are correct and documentation looks correct.  
    3. Commit changes to sgn repository and create a new pull request. With the new pool github through github action will check if there are any changes in `r_markdown_docs` folder and if yes, will trigger a gitaction to automatically build documentation on github containers.   
    4. If build action will pass, then when the branch with documation changes is merged with master, Gitaction workflow automatically builds proper gitbook html document, and pdf, and then deploy static version of html to github pages.  
    That process is completely automated. 
   
    * Build and check locally in RStudio
    * Commit changes in `r_markdown_docs` folder and create pull request
    * Check if the GitHub Action test for building documentation passes.
    * Merge to master and check GitHub Action workflow result. 


For markdown Gitbook syntax
https://bookdown.org/yihui/rmarkdown/markdown-syntax.html

# Basic syntax.

### Emphasis

*italic*   **bold**

_italic_   __bold__

### Headers

# Header 1
## Header 2
### Header 3

### Lists

Unordered List:
* Item 1
* Item 2
    + Item 2a
    + Item 2b

Ordered List:
1. Item 1
2. Item 2
3. Item 3
    + Item 3a
    + Item 3b

### R Code Chunks
R code will be evaluated and printed

```{r}
summary(cars$dist)
summary(cars$speed)
```

### Inline R Code
There were `r nrow(cars)` cars studied

### Links
Use a plain http address or add a link to a phrase:

http://example.com

[linked phrase](http://example.com)

### Images
Images on the web or local files in the same directory:

![](http://example.com/logo.png)

![optional caption text](figures/img.png)

### Blockquotes
A friend once said:

> It's always better to give
> than to receive.

### Plain Code Blocks
Plain code blocks are displayed in a fixed-width font but not evaulated

```
This text is displayed verbatim / preformatted
```
### Inline Code

We defined the `add` function to compute the sum of two numbers.

Inline equation:
$equation$

Display equation:

$$ equation $$

### Horizontal Rule / Page Break
Three or more asterisks or dashes:

******

------
Tables
First Header  | Second Header
------------- | -------------
Content Cell  | Content Cell
Content Cell  | Content Cell
Reference Style Links and Images

### Links
A [linked phrase][id].
At the bottom of the document:

[id]: http://example.com/ "Title"

### Images
![alt text][id]
At the bottom of the document:
[id]: figures/img.png "Title"

### Manual Line Breaks
End a line with two or more spaces:

Roses are red,  
Violets are blue.

### Miscellaneous
superscript^2^
~~strikethrough~~