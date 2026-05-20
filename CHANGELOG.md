# CHANGELOG

## sgn-453.1

- Compare code changes for [v452.0 to v453.1](https://github.com/BFF-AFIRMS/sgn/compare/sgn-453.1..sgn-452.0).

### SGN

The following changes come from the upstream solgenomics repository.

| Pull Request                                              | Type    | Branch                                                  | Description                                                                                                               |
| --------------------------------------------------------- | ------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| [PR #6054](https://github.com/solgenomics/sgn/pulls/6054) | Bug     | solgenomics/topic/fix_open_pedigree_in_labeldesigner    | In the labelwriter, pedigrees with missing male parent are not shown                                                      |
| [PR #6051](https://github.com/solgenomics/sgn/pulls/6051) | Bug     | solgenomics/topic/cross_and_family_in_trials            | Allow seedlots from family members as sources of plots in trial with family trial stock type                              |
| [PR #6067](https://github.com/solgenomics/sgn/pulls/6067) | Bug     | solgenomics/topic/fix_treatment_conversion_for_cross    | Exclude also cross and family_name from phenotype assignments                                                             |
| [PR #6070](https://github.com/solgenomics/sgn/pulls/6070) | Bug     | solgenomics/topic/fix_multiple_ontology_patch           | Fix package name for db patch                                                                                             |
| [PR #6072](https://github.com/solgenomics/sgn/pulls/6072) | Bug     | solgenomics/topic/fix_treatments_in_boxplotter          | Integrates the new treatment system with brapi events and observationunits to make the boxplotter work again.             |
| [PR #6055](https://github.com/solgenomics/sgn/pulls/6055) | Bug     | solgenomics/topic/fix-d3-fieldlayout-plots              | Fix trial detail page d3 plots disappearance                                                                              |
| [PR #6086](https://github.com/solgenomics/sgn/pulls/6086) | Bug     | BFF-AFIRMS/setraver/upstream/fix-upload-genotype        | Fix server errors when clicking next step in upload genotyping dialog                                                     |
| [PR #6064](https://github.com/solgenomics/sgn/pulls/6064) | Bug     | solgenomics/topic/download_upload_phenotype             | fixes downloading traits with date format YYYY-MM-DD                                                                      |
| [PR #6076](https://github.com/solgenomics/sgn/pulls/6076) | Bug     | solgenomics/topic/fix_accession_swap_duplicates         | Adds a unique_only_columns hash to the generic file parser to denote column names that cannot have duplicated row entries |
| [PR #6094](https://github.com/solgenomics/sgn/pulls/6094) | Feature | solgenomics/topic/add_links_to_plot_details             | Adds relevant hyperlinks to popup dialog on field layout viewer.                                                          |
| [PR #6061](https://github.com/solgenomics/sgn/pulls/6061) | Feature | solgenomics/topic/remove_field_fillers                  | Adds a button to remove all filler plots in a field                                                                       |
| [PR #6053](https://github.com/solgenomics/sgn/pulls/6053) | Feature | solgenomics/topic/pheno_download_trait_synonyms         | Include Trait Synonyms in Trial Downloads                                                                                 |
| [PR #6034](https://github.com/solgenomics/sgn/pulls/6034) | Feature | solgenomics/add-markers-prot                            | add option to append markers to genotype protocol during VCF upload                                                       |
| [PR #6081](https://github.com/solgenomics/sgn/pulls/6081) | Bug     | solgenomics/topic/remove_treatment_projects_in_download | Remove treatment projects and integrate new treatments into downloads                                                     |
| [PR #6098](https://github.com/solgenomics/sgn/pulls/6098) | Feature | solgenomics/topic/file_upload_unique_columns            | File upload unique columns for the Generic File Parser                                                                    |
| [PR #6105](https://github.com/solgenomics/sgn/pulls/6105) | Bug     | BFF-AFIRMS/topic/export-0-value-phenotypes              | Phenotype exports change values with '0' to an empty string #6104                                                         |
| [PR #6103](https://github.com/solgenomics/sgn/pulls/6103) | Bug     | BFF-AFIRMS/setraver/upstream/new-unit-zero              | New unit scale will not persist '0' values                                                                                |
| [PR #6101](https://github.com/solgenomics/sgn/pulls/6101) | Feature | solgenomics/topic/vector_upload                         | Generic File Parser for vector upload and fix stockprop update                                                            |
| [PR #6109](https://github.com/solgenomics/sgn/pulls/6109) | Bug     | solgenomics/topic/fix_vector_upload_unique_columns      | Changes the unique_only_columns definition in the Vector Generic Upload plugin from a hash to an array                    |
| [PR #6059](https://github.com/solgenomics/sgn/pulls/6059) | Bug     | quicksearch                                             | QuickSearch improve error checking to avoid bot use                                                                       |

### BFF-AFIRMS

The following changes are unique to the BFF-AFIRMS repository.

| Pull Request                                         | Type    | Branch                                            | Description                                                           |
| ---------------------------------------------------- | ------- | ------------------------------------------------- | --------------------------------------------------------------------- |
| [PR #41](https://github.com/BFF-AFIRMS/sgn/pulls/41) | Feature | BFF-AFIRMS/topic/content-update-projects-homepage | Search: Add the treatments search page to the navbar                  |
| [PR #43](https://github.com/BFF-AFIRMS/sgn/pulls/43) | Feature | BFF-AFIRMS/topic/spatial-layout-seedlot-download  | Trial: Add ability to include seedlot name in spatial layout download |
| [PR #67](https://github.com/BFF-AFIRMS/sgn/pulls/67) | Bug     | BFF-AFIRMS/topic/edit-unit-ontology-props         | Ontology: Can't edit properties of a unit or scale                    |
| [PR #12](https://github.com/BFF-AFIRMS/sgn/pulls/12) | Bug     | BFF-AFIRMS/topic/folders-for-genotyping           | Folder created in trials page cannot be used for genotyping           |
| [PR #40](https://github.com/BFF-AFIRMS/sgn/pulls/40) | Bug     | BFF-AFIRMS/topic/fix-wrong-identifier-prefix      | Trial: wrong identifier prefix                                        |
| [PR #39](https://github.com/BFF-AFIRMS/sgn/pulls/39) | Bug     | BFF-AFIRMS/topic/broken-treatment-with-seedlots   | Treatment: Adding to trial with linked seedlots causes error          |

## sgn-453.0
 
> This tag does not pass CI, due to two conflicting pull requests ([PR #6101](https://github.com/solgenomics/sgn/pulls/6101), [PR #6098](https://github.com/solgenomics/sgn/pulls/6098)).    
> We will release the next commit that passes CI tests as version 453.1.
