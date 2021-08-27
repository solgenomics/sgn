use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use JSON::Any;
use Data::Dumper;
use Test::WWW::Mechanize;
use JSON;

use SGN::Model::Cvterm;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;


my $fix = SGN::Test::Fixture->new();
my $chado_schema = $fix->bcs_schema;
my $metadata_schema = $fix->metadata_schema;
my $phenome_schema = $fix->phenome_schema;
my $dbh = $fix->dbh;

#
# CREATE A TEST TRIAL
#

my $ayt_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'Advanced Yield Trial', 'project_type')->cvterm_id();

my @stock_names = ('test_accession1', 'test_accession2', 'test_accession3', 'test_accession4', 'test_accession5');

my $trial_design = CXGN::Trial::TrialDesign->new();
$trial_design->set_trial_name("test_trial");
$trial_design->set_stock_list(\@stock_names);
$trial_design->set_plot_start_number(1);
$trial_design->set_plot_number_increment(1);
$trial_design->set_plot_layout_format("zigzag");
$trial_design->set_number_of_blocks(2);
$trial_design->set_design_type("RCBD");
$trial_design->calculate_design();
ok(
    my $design = $trial_design->get_design(),
    "create trial design"
);

ok(
    my $trial_create = CXGN::Trial::TrialCreate->new({
        chado_schema => $chado_schema,
        dbh => $dbh,
        owner_id => 41,
        design => $design,
        program => "test",
        trial_year => "2015",
        trial_description => "test description",
        trial_location => "test_location",
        trial_name => "subplot_test_trial",
        trial_type=>$ayt_cvterm_id,
        design_type => "RCBD",
        operator => "janedoe"
    }), 
    "create trial object"
);

my $save = $trial_create->save_trial();
ok(my $trial_id = $save->{'trial_id'}, "save trial");


#
# ADD SUBPLOTS TO PLOTS
#

my $trial = CXGN::Trial->new({ 
    bcs_schema => $chado_schema, 
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $trial_id 
});
$trial->create_subplot_entities('2');

my $tl = CXGN::Trial::TrialLayout->new({ schema => $chado_schema, trial_id => $trial_id, experiment_type => 'field_layout' });
my $d = $tl->get_design();

my @subplot_names = ();
my @subplot_names_flat = ();
foreach my $plot_num (keys %$d) {
    push @subplot_names, $d->{$plot_num}->{'subplot_names'}
}
foreach my $subplot_name_arr_ref (@subplot_names) {
    foreach (@$subplot_name_arr_ref) {
        push @subplot_names_flat, $_;
    }
}

#print STDERR Dumper \@subplot_names_flat;
# 5 plots/block * 2 blocks * 2 subplots/plot = 20 subplots
is(scalar(@subplot_names_flat), 20);


#
# ADD PLANTS TO SUBPLOTS
#

$trial->create_plant_subplot_entities(4);
$tl = CXGN::Trial::TrialLayout->new({ schema => $chado_schema, trial_id => $trial_id, experiment_type => 'field_layout' });
$d = $tl->get_design();

my @plant_names = ();
my @plant_names_flat = ();
foreach my $plot_num (keys %$d) {
    push @plant_names, $d->{$plot_num}->{'plant_names'}
}
foreach my $plant_name_arr_ref (@plant_names) {
    foreach (@$plant_name_arr_ref) {
        push @plant_names_flat, $_;
    }
}

# print STDERR Dumper \@plant_names_flat;
# 5 plots/block * 2 blocks * 2 subplots/plot * 4 plants/subplot = 80 plants
is(scalar(@plant_names_flat), 80);


#
# Remove Trial
#
$trial->delete_metadata();
$trial->delete_field_layout();
$trial->delete_project_entry();


done_testing();