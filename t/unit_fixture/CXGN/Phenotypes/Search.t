use strict;

use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::Phenotypes::Search;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();

my $phenotypes_search_fast = CXGN::Phenotypes::Search->new({
    bcs_schema=>$f->bcs_schema(),
    trait_list=>[],
    trial_list=>["141"],
    accession_list=>[],
    plot_list=>[],
    plant_list=>[],
    include_timestamp=>0,
    trait_contains=>[""],
    phenotype_min_value=>'',
    phenotype_max_value=>'',
    data_level=>'plot',
    search_type=>'fast'
});

my @fast_data = $phenotypes_search_fast->get_extended_phenotype_info_matrix();
my $first_data_row = $fast_data[1];
my $last_data_row = pop @fast_data;

is_deeply($first_data_row, '2014	141	trial2 NaCRRI	CRD	23	test_location	38878	UG120001		plot	39998	UG120001_block:1_plot:TP1_2012_NaCRRI	1	1	1	33	9	11	0.45', 'trial2 NaCRRI pheno search test fast 1st row');

is_deeply($last_data_row, '2014	141	trial2 NaCRRI	CRD	23	test_location	39997	UG120308		plot	40304	UG120308_block:14_plot:TP308_2012_NaCRRI	1	14	308	43.4	1	2	0.33', 'trial2 NaCRRI pheno search test fast last row');

 my $phenotypes_search_complete = CXGN::Phenotypes::Search->new({
     bcs_schema=>$f->bcs_schema(),
     trait_list=>[],
     trial_list=>["141"],
     accession_list=>[],
     plot_list=>[],
     plant_list=>[],
     include_timestamp=>0,
     trait_contains=>[""],
     phenotype_min_value=>'',
     phenotype_max_value=>'',
     data_level=>'plot',
     search_type=>'complete'
 });

 my @complete_data = $phenotypes_search_complete->get_extended_phenotype_info_matrix();
 $first_data_row = $complete_data[1];
 $last_data_row = pop @complete_data;
 is_deeply( $first_data_row, '2014	141	trial2 NaCRRI	CRD	23	test_location	38878	UG120001		plot	39998	UG120001_block:1_plot:TP1_2012_NaCRRI	1	1	1	33	9	11	0.45', 'trial2 NaCRRI pheno search test complete 1st row');

 is_deeply($last_data_row, '2014	141	trial2 NaCRRI	CRD	23	test_location	39997	UG120308		plot	40304	UG120308_block:14_plot:TP308_2012_NaCRRI	1	14	308	43.4	1	2	0.33', 'trial2 NaCRRI pheno search test complete last row');

   my $phenotypes_search_with_min = CXGN::Phenotypes::Search->new({
       bcs_schema=>$f->bcs_schema(),
       trait_list=>[],
       trial_list=>["141"],
       accession_list=>[],
       plot_list=>[],
       plant_list=>[],
       include_timestamp=>0,
       trait_contains=>["dry matter content percentage"],
       phenotype_min_value=>40,
       phenotype_max_value=>'',
       data_level=>'plot',
       search_type=>'fast'
   });

   my @data_with_min = $phenotypes_search_with_min->get_extended_phenotype_info_matrix();
   $first_data_row = $data_with_min[1];
   is_deeply($first_data_row, '2014	141	trial2 NaCRRI	CRD	23	test_location	38881	UG120004		plot	40001	UG120004_block:1_plot:TP4_2012_NaCRRI	1	1	4	42.1', 'trial2 NaCRRI pheno search with min');

 my $phenotypes_search_no_values = CXGN::Phenotypes::Search->new({
     bcs_schema=>$f->bcs_schema(),
     trait_list=>[],
     trial_list=>["137"],
     accession_list=>[],
     plot_list=>[],
     plant_list=>[],
     include_timestamp=>0,
     trait_contains=>[""],
     phenotype_min_value=>'',
     phenotype_max_value=>'',
     data_level=>'plot',
     search_type=>'fast'
 });

 my @data_no_values = $phenotypes_search_no_values->get_extended_phenotype_info_matrix();
 is_deeply(@data_no_values, 'studyYear	studyDbId	studyName	studyDesign	locationDbId	locationName	germplasmDbId	germplasmName	germplasmSynonyms	observationLevel	observationUnitDbId	observationUnitName	replicate	blockNumber	plotNumber', 'test trial no data');

done_testing();
