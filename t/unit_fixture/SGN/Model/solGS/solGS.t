# use strict;
# use warnings;

# use lib 't/lib';
use Test::More;
# use SGN::Test::WWW::Mechanize;

# BEGIN {use_ok('SGN::Model::solGS::solGS');}

# BEGIN {require_ok('Moose');}
# BEGIN {require_ok('Catalyst::Model');}

# my $test = SGN::Test::WWW::Mechanize->new();

# my $plot_name  = '5814_plot_0186_1_2006/07_Onne';
# my $clone_name = 'TMS000203';
# my $project_id = 128;
# my $trait_name = 'cassava mosaic disease severity';
# my $trait_id   = 70762;
# my $page       = 1;

# my $model = SGN::Model::solGS::solGS->new()->ACCEPT_CONTEXT($test->context);

# ok($model, 'created model object...ok');

# ok($model->search_trait($trait_name, $page), 'search_trait...ok');
# ok($model->all_gs_traits(), 'all_gs_traits...ok');
# ok($model->search_populations($trait_id, 1), 'search_populations...ok');

# ok($model->project_year($project_id), 'project_year...ok');
# ok($model->project_location($project_id), 'project_location...ok');
# ok($model->all_projects($page), 'all_projects...ok');
# ok($model->project_details($project_id), 'project_details...ok');

# ok($model->get_population_details($project_id), 'get_population_details...ok');

# ok($model->trait_name($trait_id), 'trait_name...ok');
# ok($model->get_trait_id($trait_name), 'get_trait_id...ok');

# ok($model->check_stock_type($project_id), 'check_stock_type...ok');
# ok($model->get_stock_owners($project_id), 'get_stock_owners...ok');

# ok($model->project_subject_stocks_rs($project_id), 'project_subject_stocks_rs..ok');

# my $stock_subj_rs = $model->project_subject_stocks_rs($project_id);
# ok($model->stocks_object_rs($stock_subj_rs), 'stocks_object_rs...ok');

# my $stock_obj_rs = $model->stocks_object_rs($stock_subj_rs);
# ok($model->stock_genotypes_rs($stock_obj_rs), 'stock_genotypes_rs...ok');

# my $stock_genotype_rs = $model->stock_genotypes_rs($stock_obj_rs);
# ok($model->extract_project_markers($stock_genotype_rs), 'extract_project_markers...ok');

# ok($model->search_stock($clone_name), 'search_stock...ok');
# ok($model->search_stock_using_plot_name($plot_name), 'search_stock_using_plot_name...ok');

# my $stock_rs = $model->search_stock($clone_name);  
# ok($model->individual_stock_genotypes_rs($stock_rs), 'individual_stock_genotypes_rs...ok');

# ok($model->genotype_data($project_id), 'genotype_data...ok');

# #ok($model->format_user_list_genotype_data(), 'format_user_list_genotype_data...ok');
# #stock_genotype_values
# #prediction_pops
# #format_user_reference_list_phenotype_data
# #geno_data
# #phenotype_data
# #phenotype_by_trait

# my $stock_plot_rs = $model->search_stock_using_plot_name($plot_name);
# ok($model->stock_phenotype_data_rs($stock_plot_rs), 'stock_phenotype_data_rs...ok');

# ok($model->stock_projects_rs($stock_rs), 'stock_projects_rs...ok');

# my $plot_id = $stock_plot_rs->single->stock_id;
# ok($model->map_subject_to_object($plot_id), 'map_subject_to_object...ok');
 
done_testing;


