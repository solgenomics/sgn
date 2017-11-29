---
title: "2. Searching the database"
layout: doc_page
---

<!-- TOC-START -->
* TOC
{:toc}
<!-- TOC-END -->

You can search for information on the database by using the following search options: Wizard, which uses combined criteria specified by users; Accessions and Plots; Trials; Markers; Images; People; FAQ.

![search1.png]({{'assets/images/image267.png' | relative_url }})


2.1 The Search Wizard {#search-wizard}
---------------------

![]({{"assets/images/image154.png" | relative_url }})

### 2.1.1 How the Search Wizard Works

The search wizard presents a number of select boxes, which are initially empty. You start searching by picking a category of data from the dropdown above the left-most select box.

Once a category has been picked, the database will retrieve all the options within this category and display them within the first select box. You then select one or more options from the first select box, which activates the second dropdown.

You can then select a category from the second dropdown, and repeat this same search process through all four dropdowns and select boxes.

![]({{"assets/images/image135.png" | relative_url }})

-   In the example above, the "locations" category was chosen in the first dropdown. The first select box then displayed all the possible locations in the database. The option Ibadan was selected.

-   This activated the second dropdown. The category “years” was chosen in the second dropdown. The second select box then displayed all the years that are linked in the database to the location Ibadan. From that list, the options 2011 and 2012 were selected.

-   This activated the third dropdown. A final category, “accessions”, was chosen in the third dropdown. The third select box was then populated with the 3847 accessions in the database that are linked with the location Ibadan in the years 2011 or 2012.

In addition to the basic search operations demonstrated above, users can take advantage of two more tools:

**“Start from a list”** dropdown <img src='{{"assets/images/image243.png" | relative_url }}' alt="startfromlist.png" width="211" height="41" />

-   Instead of picking a category in the first dropdown, users can instead populate the first selectbox from a list using “Start from a list” button. This is useful for starting queries with a list of accessions, or plots, as these categories are not among the options in the first dropdown.

**AND/OR** Toggle <img src='{{"assets/images/image269.png" | relative_url }}' alt="or.png" width="87" height="34" /> <img src='{{"assets/images/image88.png" | relative_url }}' alt="and.png" width="87" height="39" />

-   By default, the search wizard combines options within a category using an OR query. In the example above, in the third panel the wizard retrieved accessions associated with the location ‘Ibadan’ in the years “2011 **OR** 2012”

-   -   If the user clicked the toggle below the second select box to change it to AND before choosing accessions in the third dropdown, the wizard would instead retrieve accessions associated with the location ‘Ibadan’ in the years “2011 AND 2012”. This will be a smaller set of accessions, because any accessions used only in 2011, or only in 2012 will be excluded.

### 2.1.2 How to use retrieved data 

#### Getting more Info

Any option in the wizard select boxes (except for years) can be double-clicked to open a page with more details. The new page is opened in a new tab.

#### Saving to a list

You can store the highlighted items in any selected box to lists. This is done using the inputs and buttons directly below the select box. **Don’t forget, you must be logged in to work with lists!**

![]({{"assets/images/image273.png" | relative_url }})

-   To **store items to a new list**, first type a new list name in the text input on the left. Then click on the "add to new list" button. A popup window will confirm the action, and display the number of items added to your new list.

-   To **add items to an existing list**, first pick an existing list using the dropdown on the left. Then click the the "add to list" button. A popup window will confirm the action, and display the number of items added to your existing list.

#### Downloading Data

You can download phenotypes and genotypes associated with the highlighted items in the wizard select boxes. This is done using the buttons in the download section at the bottom of the page. **Don’t forget, you must be logged in to download data!**

![]({{"assets/images/image321.png" | relative_url }})

##### Phenotypes

The phenotypes download is quite flexible, and can download a subset of all the trial data in the database based on whichever categories and options you currently have selected. Simply click on the “Download Phenotypes” button, review the popup, changing or adding any additional parameters you like, then click ‘Submit’. If you chose the ‘complete’ download option, the download may take awhile.

![]({{"assets/images/image189.png" | relative_url }})

##### Genotypes

The genotype download is more stringent. It requires a minimum of one accession and one genotyping protocol to be selected in the wizard select boxes. Text boxes on the right hand side of the page will help track what requirements have been selected. One clicked, the “Download Genotypes” button will download a simple genotype dosage file for each accession.

### 2.1.3 Updating the Wizard

The search wizard uses a copy of the database, or a cache, to return results quickly. If data appears to be missing, it usually means that the cache needs to be updated. Users with submitter privileges or above can do this using the ‘Update wizard’ link. 

![]({{"assets/images/image92.png" | relative_url }})

This will take just a few seconds in small databases, but may take a few hours to complete in larger databases.


2.2 Accessions and Plot Search
------------------------------

Accessions and their related materials (cross, plant, plot, population, tissue\_sample, training population) can be searched by using “Search Accessions and Plots” page. On this page, “accession” is the default stock type. However, you can change stock type by selecting an option from the drop-down list.

![]({{"assets/images/image316.png" | relative_url }})

You can also use “Search Accessions and Plots” page to add new stocks by clicking on “Submit New Stock”.

### *IMPORTANT!* Before entering a stock
**Before you enter a new stock manually, make sure that the stock does not already exist in the database. Please use the "Accession and plots" search to search for the stock by name and several possible synonyms. *Enter the stock only if you don't find it in the database!***

### Entering a Stock

![]({{"assets/images/image86.png" | relative_url }})

Clicking on the “Submit New Stock” link will redirect you to the “Create a New Stock” form. To submit new stock, you must login and have an account that has submitter privilege. To change your account status from “user” to “submitter”, you must contact the database curators. To learn how to change your account status, click here.

![]({{"assets/images/image284.png" | relative_url }})

The organism field is an autocomplete field for the organism. Start typing, and the matching organisms in the database will be shown in the drop-down list. (_i.e._ For cassava, select Manihot esculenta.) The stock name should be a standard name given to the stock at a national facility. The unique name is usually the same as the stock name. After completing the form, click on “Store” button to finish the process.

### Other information

You can add other information, such as synonyms, descendants, images, literature annotations, ontology annotations, phenotypes, and genotypes, directly on “Stock Details” page.

2.3 Trials Search
-----------------

Trials on the database can be searched based on trial name, description, breeding program, year, location, trial type, design, planting date, and harvest date.

![]({{"assets/images/trial_search.png" | relative_url }})

2.4 Trait Search
-----------------

On the Trait Search page (menu item `Search > Traits`), traits in the database can be searched by ID, name, or descripiton. Selecting traits in the results of the search allows one to add the selected results to a trait list, or create a new trait list from the select results.
![]({{"assets/images/trait-search.png" | relative_url }})
