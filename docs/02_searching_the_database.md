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

You can download trial meta-data, phenotypes and genotypes associated with the highlighted items in the wizard select boxes. This is done using the buttons in the download section at the bottom of the page. **Don’t forget, you must be logged in to download data!**

![]({{"assets/images/image321.png" | relative_url }})

##### meta-data

Trial meta-data can be downloaded by selecting a subset of trials from the database or based on your search categories.  To download, click on "Download Meta-data", a dialog will appear. Select download format and click the "Submit" button to complete your download. 

![]({{"assets/images/wizard_metadata_download.png" | relative_url }})

##### Phenotypes

The phenotypes download is quite flexible, and can download a subset of all the trial data in the database based on whichever categories and options you currently have selected. Simply click on the “Download Phenotypes” button, review the popup, changing or adding any additional parameters you like, then click ‘Submit’. If you chose the ‘complete’ download option, the download may take awhile.

![]({{"assets/images/image189.png" | relative_url }})

##### Genotypes

The genotype download is more stringent. It requires a minimum of one accession and one genotyping protocol to be selected in the wizard select boxes. Text boxes on the right hand side of the page will help track what requirements have been selected. One clicked, the “Download Genotypes” button will download a simple genotype dosage file for each accession.

#### Saving the wizard selections

As discussed above, the selections of the individual select boxes in the wizard can be saved separately to a list. The lists can be used as inputs in other tools on the site. However, sometimes creating a selection is quite time consuming and restoring the selections from four different lists would be cumbersome too. Therefore, the selections can be saved together in a dataset, and named for later retrieval. This is done in the section "Save current selection" that is below the "Download" section. When the button named "Save current selection" is clicked, it brings up a dialog box that allows to name the selection. Clicking on "Save" in the dialog box saves the selection dataset, "Cancel" closes the dialog without saving. Next to the "Save current selection" button is a pull down menu which can be used to manage stored datasets. A particular dataset can be chosen, and the buttons beneath the pull down can be used to retrieve the dataset to be displayed on the wizard ("Show on wizard"), display some data about the dataset ("View metadata"), or to delete the dataset ("Delete").

![]({{"assets/images/wizard_save_current_selection.png" | relative_url }})

### 2.1.3 Updating the Wizard

The search wizard uses a copy of the database, or a cache, to return results quickly. If data appears to be missing, it usually means that the cache needs to be updated. Users with submitter privileges or above can do this using the ‘Update wizard’ link. 

![]({{"assets/images/image92.png" | relative_url }})

This will take just a few seconds in small databases, but may take a few hours to complete in larger databases.


2.2 Accessions and Plot Search
------------------------------

Accessions and their related materials (cross, plant, plot, population, tissue\_sample, training population) can be searched by using “Search Accessions and Plots” page. On this page, “accession” is the default stock type; however, you can change stock type by selecting an option from the drop-down list.
From this page you can construct detailed queries for stock types. For example, by using the "Usage" section, the "Properties" section, and the "Phenotypes" section you could search for accessions which were diploids used in a specific year and location and were also phenotyped for height. You can also search for accessions based on genetic properties, such as the location of an introgression on a specific chromosome.

![]({{"assets/images/search_accessions.png" | relative_url }})

It is possible to query over any of the available properties, such as "ploidy_level", "country of origin", "introgression_chromosome", etc.

![]({{"assets/images/search_accessions_properties_search.png" | relative_url }})

In the search result table it is possible to select any of the available properties to view.

![]({{"assets/images/search_accessions_properties_view.png" | relative_url }})

At the bottom of the accession search there is a phenotype graphical filtering tool. Here you can filter down accessions based on combinations of trait performance. The filtered down accessions are then able to be saved to a list.

![]({{"assets/images/search_accessions_graphical_filtering.png" | relative_url }})

For information on adding Accessions please see the Managing Accessions help.
For information on how field trial plots, plants, tissue samples, and subplots are added to the database, please see the Managing Field Trials help.

2.3 Trials Search
-----------------

Trials on the database can be searched based on trial name, description, breeding program, year, location, trial type, design, planting date, and harvest date.

![]({{"assets/images/trial_search.png" | relative_url }})

2.4 Trait Search
-----------------

On the Trait Search page (menu item `Search > Traits`), traits in the database can be searched by ID, name, or descripiton. Optionally, a starting list of traits can be selected to filter down results.

![]({{"assets/images/trait-search-default.png" | relative_url }})

Selecting traits in the results of the search allows one to add the selected results to a trait list, or create a new trait list from the select results.

![]({{"assets/images/trait-search.png" | relative_url }})

2.5 Ontology Browser
-----------------

A more advanced tool for searching for Traits is the ontology browser, available by clicking on Analyze and Ontology Browser. From here you can search ontologies and see the various classifications of terms in a tree display.

![]({{"assets/images/ontology_browser.png" | relative_url }})

The terms which appear in the Trait Search in 2.4 are only variable terms. The ontology browser shows these variables as different from their grouping terms by indicating VARIABLE_OF like in the following screenshot.

![]({{"assets/images/ontology_browser_variable.png" | relative_url }})

2.6 Search Seedlots
-----------------

Seedlots are different from Accessions in that they represent the physical seed being evaluated in an experiment. Seedlots have things like physical storage locations and seed quantities, which accessions do not. To search for available seedlots you go to Manage and then click Seed Lots. By clicking Search Seedlots, you can specify query information. The results from your search will be in the table below the search form.

![]({{"assets/images/search_seedlots.png" | relative_url }})

![]({{"assets/images/manage_seedlots.png" | relative_url }})

