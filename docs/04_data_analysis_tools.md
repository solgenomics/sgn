---
title: "4. Data Analysis Tools"
layout: doc_page
---

<input type="hidden" toc="start" />
* TOC
{:toc}
<input type="hidden" toc="end" />

CassavaBase provides several tools for phenotype data analysis, marker-assisted selection, sequence and expression analyses, as well as ontology browser. These tools can be found in the “Analyze” menu.

![]({{"assets/images/image114.png" | relative_url }})

4.1 Selection Index
-------------------

To determine rankings of accessions based on more than one desirable trait, CassavaBase provides “Selection Index” tool that allows you to specify a weighting on each trait. To access the tool, clicking on “Selection Index” in the “Analyze” menu.

![]({{"assets/images/image251.png" | relative_url }})

On the Selection Index page, selecting a trial that you want to analyze.

![]({{"assets/images/image95.png" | relative_url }})

After you selected a trial, you can find traits that were assayed in that trial in the “Trait” box.

![]({{"assets/images/image78.png" | relative_url }})

Selecting a trait that you want to include in the analysis will open a new dialogue showing the selected trait and a box that you can assign a “Weight” of that trait. After you are done, you can continue by selecting another trait by clicking on “Add another trait” link.

![]({{"assets/images/image304.png" | relative_url }})

After you selected another trait, this page will automatically update information for you by showing all of the traits that you selected for the analysis.

![]({{"assets/images/image76.png" | relative_url }})

You also have options to choose a reference accession, choose to include accessions with missing phenotypes, scaling values to a reference accession. After you complete your setting, clicking on “Calculate Rankings”

![]({{"assets/images/image343.png" | relative_url }})

The Selection Index tool will generate rankings of accessions based on the information that you specified. You can copy the results to your system clipboard, convert the table data to CSV format, or print the data.

![]({{"assets/images/image326.png" | relative_url }})

Clicking on “Raw Average” will display average values of the phenotypes of those ranked accessions.

![]({{"assets/images/image150.png" | relative_url }})

Selection Index tool also allows you to save top ranked accessions directly to “Lists”. You can retrieve top ranked accessions by selecting a number or a percent.

![]({{"assets/images/image156.png" | relative_url }})

4.2 Genomic Selection
---------------------

The prediction of breeding values for a trait is a one step or two steps process, depending on what stage in your breeding cycle you are. The first step is to build a prediction model for a trait using a training population of clones with phenotype and genotype data. If you have yet to select parents for crossing for your first cycle of selection you can use the breeding values of the training population. If you are at later stages of your selection program, you need to do the second step which is applying the prediction model on your selection population. All clones in your training and selection populations must exist in the database.

To use the genomic selection tool, on [*cassavabase.org,*](http://cassavabase.org/) from the 'analyze' pull-down menu, select 'Genomic Selection'.

![]({{"assets/images/image247.png" | relative_url }})

### 4.2.1 Building a prediction model

There are three ways to build a model for a trait.

#### Method 1:

One way to build a model is, using a trait name, to search for trials in which the trait was phenotyped and use a trial or a combination of trials to build a model for the trait. For example, if you search for 'mosaic disease severity, you will get a list of trials you can use as training populations.

![]({{"assets/images/image160.png" | relative_url }})

You will get a list of trials (as shown below) in which the trait of your interested was phenotyped. From the list, you can use a single trial as a training population or combine several trails to form a training population for the prediction model of the trait. Let's say, you want to create a training population using individuals from trials 'cassava ibadan 2001/02' and 'cassava ibadan 02/03' and build a model for 'cassava mosaic disease severity' using all clones from the training population.

![]({{"assets/images/image249.png" | relative_url }})

Select the trials to combine (the same coloured), click ‘done selecting’, click the 'combine trials and build model' button, and you will get a model and its output for the trait. On the model detail page, you can view the description of input data used in the model, output from the model and search interface for selection populations the model you can apply to predict their breeding values. The description of the input data for the model includes the number of phenotyped clones, and the number of markers, scatter and frequency distribution plots for the phenotype data, relationship between the phenotype data and GEBVs, population structure. The model output includes model parameters, heritability of the trait , prediction accuracy, GEBVs of the individuals from the training population and marker effects.

![]({{"assets/images/image330.png" | relative_url }})

Expand each section to see detailed information.

If you expand the ‘Trait phenotype data’ section, you will find plots to explore the phenotype data used in the model. You can assess the phenotype data using a scatter and histogram plots and the descriptive statistics.

<img src='{{"assets/images/image244.png" | relative_url }}' width="380" />

<img src='{{"assets/images/image263.png" | relative_url }}' width="499" />

A regression line between observed phenotypes and GEBVs shows the relationship between the two.

![]({{"assets/images/image83.png" | relative_url }})

You can also explore if there is any sub-clustering in the training population using PCA.

<img src='{{"assets/images/image93.png" | relative_url }}' width="389" />

To check the model accuracy, a 10-fold cross-validation test, expand the ‘model accuracy’ section.

<img src='{{"assets/images/image328.png" | relative_url }}' width="402" />

Marker effects are also available for download. To do so, expanad the ‘Marker Effects’ section and click the ‘Download all marker effects’ link and you will get a tab delimited output to save on your computer.

<img src='{{"assets/images/image74.png" | relative_url }}' width="493" />

The breeding values of the individuals used in the training population are displayed graphically. Mousing over each data point displays the clone and its breeding value. To examine better, you can zoom in into the plot by selecting an area on the plot. You can download them also by following the 'Download all GEBVs' link.

<img src='{{"assets/images/image147.png" | relative_url }}' width="578" />


##### Estimating breeding values in a selection population

If you already have a selection population (in the database), from the same model page, you can apply the model to the selection population and estimate breeding values for all the clones in the population. You can search for a selection population of clones in the database using the search interface or you can make a custom list of clones using the [*list interface*](http://cassavabase.wikispaces.com/Lists). if you click the 'search for all relevant selection populations', you will see all relevant selection populations for that model. However, this option takes long time decause of the large set of populations in the database and the filtering. Therefore, the fastest way is to search for each of your selection populations by name. If you are logged in to the website you will also see a list of your custom set of genotyped clones.

![]({{"assets/images/image338.png" | relative_url }})

To apply the model to a selection population, simply click your population name or 'Predict Now' and you will get the predicted breeding values. When you see a name of (or acronym\]) of the trait, follow the link and you will see an interactive plot of the breeding values and a link to download the breeding values of your selection population.

<img src='{{"assets/images/image334.png" | relative_url }}' width="512" />

#### Method 2

Another way to build a model is by selecting a trial, instead of selecting and searching for a specific trait. This approach is useful when you know a particular trial that is relevant to the environment you are targeting to breed material for. This method allows you to build models and predict genomic estimated breeding values (GEBVs) for several traits within a single trial at once. You can also calculate selection index for your clones when GEBVs are estimated for multiple traits.

To do this select the "Genomic Selection" link found under the "analyze" menu. This will take you to the same home page as used with Method 1. However, instead of entering information to search for in "Search for a trait", click on "Use a trait as a trial population". This will expand a new menu that will show all available trials.

![]({{"assets/images/image344.png" | relative_url }})

<img src='{{"assets/images/image329.png" | relative_url }}' alt="arrow.png" width="82" />

![]({{"assets/images/image341.png" | relative_url }})

To begin creating the model, select the existing trial that you would like to use. In this example I will be using the trial and trait data from "Cassava Ibadan 2002/03" trial. Clicking on a trial will take you to a page where you can find information such as number of markers and number of phenotypes clones.

![]({{"assets/images/image322.png" | relative_url }})

In addition to the number of phenotype clones and number of markers, the main page for the trial selected also has information and graphs on phenotypic correlation for all of the traits. By moving your cursor over the graph you can read the different values for correlation between two traits. A key with all of the trait names of the acronyms used can be found in the tab below the graph.

![]({{"assets/images/image151.png" | relative_url }})

Below the "Training population summary" there is a tab for "Traits". Clicking on this tab will show all available traits for the specific trial. You can create a model by choosing one or multiple traits in the trial and clicking "Build Model". In this example, the traits for "cassava bacterial blight severity" and "cassava mosaic disease severity" have been selected.

![]({{"assets/images/image69.png" | relative_url }})

Clicking on 'Build Model' will take you to a new page with the models outputs for the traits. Under the "Genomic Selection Model Output" tab you can view the model output and the model accuracy. Clicking on any of the traits will take you to a page with information about the model output on that individual trait within the trial. There you can view all of the trait information that was seen in more detail in [*Method 1*](http://cassavabase.wikispaces.com/Method+1%C2%A0).

![]({{"assets/images/image336.png" | relative_url }})

You can apply the models to simultaneously predict GEBVs for respective traits in a selection population by clicking on "Predict Now" or the name of the selection population. You can also apply the models to any set of genotyped clones that you can create using the 'lists' feature. For more information on lists, click [*here*](http://cassavabase.wikispaces.com/Lists). Follow the link to the trait name to view and download the predicted GEBVs for the trait in a selection population.

<img src='{{"assets/images/image171.png" | relative_url }}' width="533" />

To compare clones based on their performance on multiple traits, you can calculate selection indices using the form below. Choose from the pulldown menu the population with predicted GEBVs for the traits and assign relative weights for each trait. The relative weight of each trait must be between 0 - 1. 0 being of least weight and importance, not wanting to consider that particular trait in selecting a genotype and 1 being a trait that you give highest importance.

In this example we will be using the "Cassava Ibadan 2002/03" population and assigning values to each of the traits. Remember that there is a list of acronyms and trait names at the bottom of the page for reference. After entering whatever values you would like for each trait click on the "Calculate" button to generate results. This will create a list of the top 10 genotypes that most closely match the criteria that you entered. The list will be displayed right below the "Cassava selection index" tab. This information can also be downloaded onto your computer by clicking on the "Download selection indices" link underneath the listed genotypes and selection indices.

<img src='{{"assets/images/image81.png" | relative_url }}' width="463" />

#### Method 3

In addition to creating a model by searching for pre-existing traits or by preexisting trial name, models can also be created by using your own list of clones. This creates a model by using or creating a training population.

The page to use the third Method for creating a population model is the same as for the other two models. Select "Genomic Selection" from under the "analyze" menu of the main toolbar. This will take you to the Genomic Selection homepage and show you all three available methods to create a model. To see and use Method 3 scroll down and click on the tab labeled "Create a Training Population". This will open a set of tools that will allow you to use pre-existing lists or to create a new list.

![]({{"assets/images/image138.png" | relative_url }})

Once the "Create a Training Population" tab is opened you have the option to use a pre-existing list or create new one. To learn how to create a list, click [*here*](http://cassavabase.wikispaces.com/Lists). The "Make a new list of plots" link will take you directly to the Search Wizard that is usually used to create lists.

Please note: the only lists that can be used in Method 3 to create a model are lists of plots and trials. If the pre-existing list is not of plots or trials (for example, traits, or locations) it will not show up and cannot be used as a training population. When you create you use a list of trials, the trials data will be combined to create a training data set.

To use your custom list of plots or trials as a training population, select the list and click "Go". This will take you to a detail page for the training population.

![]({{"assets/images/image181.png" | relative_url }})

From here on you can build models and predict breeding values as described in [*Method 2*](#method-2)**.**

4.3 Genome Browsing
-------------------

There are two ways to evaluate genotype information within the browser, from an accession detail page or a trial detail page.

### 4.3.1 Browsing Genotype data by Accession

If you are interested in browsing genotype information for a single accession, for example ‘BAHKYEHEMAA’, navigate to the accession detail page.

<img src='{{"assets/images/image152.png" | relative_url }}' width="453" />

Near the bottom of the detail page is a collapsible section called “Accession Jbrowse”.<img src='{{"assets/images/image20.png" | relative_url }}' width="465" />

This section will contain a link to the accession jbrowse page if the necessary genotype data is available. Clicking the link should take you to a page that looks like this, a which point you can browsre the genotype data in the form of a vcf track aligned to the latest build of the cassava genome.

![]({{"assets/images/image318.png" | relative_url }})

### 4.3.2 Browsing Genotype data by Trial

If you are interested in browsing genotype information for the accessions within a given trial, navigate to the trial detail page. <img src='{{"assets/images/image277.png" | relative_url }}' width="565" />

Halfway down the page is a collapsible section called “Trial Jbrowse”. This section will contain a link to the trial jbrowse page if the necessary genotype data for at least two accessions planted in the trial is available.

<img src='{{"assets/images/image268.png" | relative_url }}' width="435" />

Clicking the link should take you to a page that looks like this, a which point you can browse the genotype data in the form of vcf tracks aligned to the latest build of the cassava genome.![]({{"assets/images/image327.png" | relative_url }})

4.4 Principal Component Analysis
--------------------------------

There are three ways to evaluate the population structure of a set of individuals with genotype data in the database.

(1) If the entire set of the individuals are members of an experimental trial, then search for the trial, on the trial page, go to the ‘Principal Component Analysis’ section, click the ‘Run PCA’ button and wait for the output.

(2) If the entire set of individuals are members of a training population you used to create a genomic selection model for a trait, on the model output page, go the ‘Principal Component Analysis’ section and click the ‘Run PCA’ button.

(3) If the set of individuals are members of a custom list you created, then go to the ‘analyze’ menu, select the ‘Principal Component Analysis’, log in to the site, select your list and then click ‘Run PCA’ button.

With all the options, you will get a interactive plot of the two PCs (shown below) that explain the largest variance. Point the cursor at any data point and you will see the individual name with its corresponding PCs scores. By clicking the ‘Download all PCs’, you can also download the 10 PCs scores in the text format.

<img src='{{"assets/images/image155.png" | relative_url }}' width="522" />
