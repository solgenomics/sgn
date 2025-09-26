
use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use JSON::Any;
use Data::Dumper;
use Test::WWW::Mechanize;
use JSON;
use DateTime;
use Cwd;
use File::Temp 'tempfile';

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLayoutDownload');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
BEGIN {use_ok('CXGN::TrialStatus');}
BEGIN {use_ok('CXGN::Genotype::StoreGenotypingProject');}
BEGIN {use_ok('CXGN::Trial');}
BEGIN {use_ok('CXGN::BreedersToolbox::Projects');}
BEGIN {use_ok('CXGN::Genotype::GenotypingProject');}
BEGIN {use_ok('CXGN::Trait::Treatment');}
BEGIN {use_ok('CXGN::Phenotypes::StorePhenotypes');}

ok(my $chado_schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $metadata_schema = $fix->metadata_schema);
ok(my $dbh = $fix->dbh);

# create a location for the trial
ok(my $trial_location = "test_location_for_trial");
ok(my $location = $chado_schema->resultset('NaturalDiversity::NdGeolocation')
   ->new({
    description => $trial_location,
	 }));
ok($location->insert());

# create stocks for the trial
ok(my $accession_cvterm = $chado_schema->resultset("Cv::Cvterm")
   ->create_with({
       name   => 'accession',
       cv     => 'stock_type',

		 }));
my @stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@stock_names, "test_stock_for_trial".$i);
}

#create stocks for genotyping plate
my @genotyping_stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@genotyping_stock_names, "test_stock_for_genotyping_trial".$i);
}


ok(my $organism = $chado_schema->resultset("Organism::Organism")
   ->find_or_create( {
       genus => 'Test_genus',
       species => 'Test_genus test_species',
		     }, ));

# create some test stocks
foreach my $stock_name (@stock_names) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $stock_name,
	    uniquename => $stock_name,
	    type_id     => $accession_cvterm->cvterm_id,
		 });
};

# create some genotyping test stocks
foreach my $stock_name (@genotyping_stock_names) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $stock_name,
	    uniquename => $stock_name,
	    type_id     => $accession_cvterm->cvterm_id,
		 });
};


ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("test_trial"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_number_of_blocks(2), "set block number");
ok($trial_design->set_design_type("RCBD"), "set design type");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

my $ayt_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'Advanced Yield Trial', 'project_type')->cvterm_id();

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "new_test_trial_name",
    trial_type=>$ayt_cvterm_id,
    design_type => "RCBD",
    operator => "janedoe"
						    }), "create trial object");

my $save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");


# test adding trial activity when creating trial
my %trial_activity;
$trial_activity{'Trial Created'}{'user_id'} = '41';
$trial_activity{'Trial Created'}{'activity_date'} = '2022-March-30';

my $trial_activity_obj = CXGN::TrialStatus->new({ bcs_schema => $chado_schema });
$trial_activity_obj->trial_activities(\%trial_activity);
$trial_activity_obj->parent_id($save->{'trial_id'});
ok($trial_activity_obj->store(), "added trial activity");

# test retrieving trial activity
my $people_schema = $fix->people_schema;
my @activity_list = ("Started Phenotyping", "Phenotyping Completed", "Data Cleaning Completed", "Data Analysis Completed");
my $trial_status_obj = CXGN::TrialStatus->new({ bcs_schema => $chado_schema, people_schema => $people_schema, parent_id => $save->{'trial_id'}, activity_list => \@activity_list});
my $activity_info = $trial_status_obj->get_trial_activities();
is_deeply($activity_info, [
    ['Trial Created','2022-March-30','Jane Doe'],
    ['Started Phenotyping','NA','NA'],
    ['Phenotyping Completed','NA','NA'],
    ['Data Cleaning Completed','NA','NA'],
    ['Data Analysis Completed','NA','NA']
]);


ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "new_test_trial_name",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

ok(my $accession_names = $trial_layout->get_accession_names(), "retrieve accession names1");

my %stocks = map { $_ => 1 } @stock_names;

foreach my $acc (@$accession_names) {
    ok(exists($stocks{$acc->{accession_name}}), "check accession names $acc->{accession_name}");
}

#create RCBD trial with one accession

@stock_names;
push @stock_names, "test_stock_for_trial1";

ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("new_test_trial_name_single"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_number_of_reps(2), "set rep number");
ok($trial_design->set_design_type("CRD"), "set design type");
ok($trial_design->set_plot_numbering_scheme('consecutive'));
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "new_test_trial_name_single",
    design_type => "RCBD",
    operator => "janedoe"
						    }), "create trial object");

my $save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "new_test_trial_name_single",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

ok(my $accession_names = $trial_layout->get_accession_names(), "retrieve accession names2");

my %stocks = map { $_ => 1 } @stock_names;

foreach my $acc (@$accession_names) {
    ok(exists($stocks{$acc->{accession_name}}), "check accession names $acc->{accession_name}");
}


# layout for genotyping experiment
# use data structure returned by brapi call for GDF:
# plates:[ { 'project_id' : 'project x',
#            'plate_name' : 'required',
#            'plate_format': 'Plate_96' | 'tubes',
#            'sample_type' : 'DNA' | 'RNA' | 'Tissue'
#            'samples':[
# {
#    		'name': 'sample_name1',
#     		'well': 'optional'
#               'concentration:
#'              'volume':
#               'taxomony_id' :
#               'tissue_type' :
#               }
# ]

#adding genotyping project

my $location_rs = $chado_schema->resultset('NaturalDiversity::NdGeolocation')->search({description => 'Cornell Biotech'});
my $location_id = $location_rs->first->nd_geolocation_id;

my $bp_rs = $chado_schema->resultset('Project::Project')->find({name => 'test'});
my $breeding_program_id = $bp_rs->project_id();

my $add_genotyping_project = CXGN::Genotype::StoreGenotypingProject->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    project_name => 'test_genotyping_project_1',
    breeding_program_id => $breeding_program_id,
    project_facility => 'igd',
    data_type => 'snp',
    year => '2022',
    project_description => 'genotyping project for test',
    nd_geolocation_id => $location_id,
    owner_id => 41
});
ok(my $store_return = $add_genotyping_project->store_genotyping_project(), "store genotyping project");

my $gp_rs = $chado_schema->resultset('Project::Project')->find({name => 'test_genotyping_project_1'});
my $genotyping_project_id = $gp_rs->project_id();

my $plate_info = {
    elements => \@genotyping_stock_names,
    plate_format => 96,
    blank_well => 'A02',
    name => 'test_genotyping_trial_name',
    genotyping_facility_submit => 'no',
    sample_type => 'DNA'
};

my $gd = CXGN::Trial::TrialDesign->new( { schema => $chado_schema } );
$gd->set_stock_list($plate_info->{elements});
$gd->set_block_size($plate_info->{plate_format});
$gd->set_blank($plate_info->{blank_well});
$gd->set_trial_name($plate_info->{name});
$gd->set_design_type("genotyping_plate");
$gd->calculate_design();
my $geno_design = $gd->get_design();

#print STDERR Dumper $geno_design;
is_deeply($geno_design, {
          'A09' => {
                     'row_number' => 'A',
                     'plot_name' => 'test_genotyping_trial_name_A09',
                     'stock_name' => 'test_stock_for_genotyping_trial8',
                     'col_number' => 9,
                     'is_blank' => 0,
                     'plot_number' => 'A09'
                   },
          'A07' => {
                     'is_blank' => 0,
                     'plot_number' => 'A07',
                     'plot_name' => 'test_genotyping_trial_name_A07',
                     'row_number' => 'A',
                     'col_number' => 7,
                     'stock_name' => 'test_stock_for_genotyping_trial6'
                   },
          'A02' => {
                     'is_blank' => 1,
                     'plot_number' => 'A02',
                     'row_number' => 'A',
                     'plot_name' => 'test_genotyping_trial_name_A02_BLANK',
                     'stock_name' => 'BLANK',
                     'col_number' => 2
                   },
          'A05' => {
                     'is_blank' => 0,
                     'plot_number' => 'A05',
                     'row_number' => 'A',
                     'plot_name' => 'test_genotyping_trial_name_A05',
                     'stock_name' => 'test_stock_for_genotyping_trial4',
                     'col_number' => 5
                   },
          'A08' => {
                     'plot_name' => 'test_genotyping_trial_name_A08',
                     'row_number' => 'A',
                     'col_number' => 8,
                     'stock_name' => 'test_stock_for_genotyping_trial7',
                     'is_blank' => 0,
                     'plot_number' => 'A08'
                   },
          'A04' => {
                     'plot_name' => 'test_genotyping_trial_name_A04',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_for_genotyping_trial3',
                     'col_number' => 4,
                     'is_blank' => 0,
                     'plot_number' => 'A04'
                   },
          'A01' => {
                     'is_blank' => 0,
                     'plot_number' => 'A01',
                     'plot_name' => 'test_genotyping_trial_name_A01',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_for_genotyping_trial1',
                     'col_number' => 1
                   },
          'A11' => {
                     'plot_name' => 'test_genotyping_trial_name_A11',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_for_genotyping_trial10',
                     'col_number' => 11,
                     'is_blank' => 0,
                     'plot_number' => 'A11'
                   },
          'A06' => {
                     'plot_number' => 'A06',
                     'is_blank' => 0,
                     'stock_name' => 'test_stock_for_genotyping_trial5',
                     'col_number' => 6,
                     'row_number' => 'A',
                     'plot_name' => 'test_genotyping_trial_name_A06'
                   },
          'A10' => {
                     'is_blank' => 0,
                     'plot_number' => 'A10',
                     'plot_name' => 'test_genotyping_trial_name_A10',
                     'row_number' => 'A',
                     'col_number' => 10,
                     'stock_name' => 'test_stock_for_genotyping_trial9'
                   },
          'A03' => {
                     'plot_name' => 'test_genotyping_trial_name_A03',
                     'row_number' => 'A',
                     'stock_name' => 'test_stock_for_genotyping_trial2',
                     'col_number' => 3,
                     'is_blank' => 0,
                     'plot_number' => 'A03'
                   }
        }, 'check genotyping plate design');

#store genotyping plate
my $trial = CXGN::Trial->new( { bcs_schema => $chado_schema, trial_id => $genotyping_project_id });
my $location_data = $trial->get_location();
my $location_name = $location_data->[1];
my $description = $trial->get_description();
my $genotyping_facility = $trial->get_genotyping_facility();
my $plate_year = $trial->get_year();

my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $chado_schema });
my $breeding_program_data = $program_object->get_breeding_programs_by_trial($genotyping_project_id);
my $breeding_program_name = $breeding_program_data->[0]->[1];

my $genotyping_trial_create;
ok($genotyping_trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    program => $breeding_program_name,
    trial_location => $location_name,
    operator => "janedoe",
    trial_year => $plate_year,
    trial_description => $description,
    design_type => 'genotyping_plate',
    design => $geno_design,
    trial_name => $plate_info->{name},
    is_genotyping => 1,
    genotyping_user_id => 41,
    genotyping_project_id => $genotyping_project_id,
    genotyping_facility_submitted => $plate_info->{genotyping_facility_submit},
    genotyping_facility => $genotyping_facility,
    genotyping_plate_format => $plate_info->{plate_format},
    genotyping_plate_sample_type => $plate_info->{sample_type},
}), "create genotyping plate");

my $save = $genotyping_trial_create->save_trial();
ok($save->{'trial_id'}, "save genotyping plate");

ok(my $genotyping_trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "test_genotyping_trial_name",
}), "lookup genotyping plate");
ok(my $genotyping_trial = $genotyping_trial_lookup->get_trial(), "retrieve genotyping plate");
ok(my $genotyping_trial_id = $genotyping_trial->project_id(), "retrive genotyping plate id");
ok(my $genotyping_trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $genotyping_trial_id,
    experiment_type => 'genotyping_layout'
}), "create trial layout object for genotyping plate");
ok(my $genotyping_accession_names = $genotyping_trial_layout->get_accession_names(), "retrieve accession names3");
my %genotyping_stocks = map { $_ => 1 } @genotyping_stock_names;
$genotyping_stocks{'BLANK'} = 1;
foreach my $acc (@$genotyping_accession_names) {
    ok(exists($genotyping_stocks{$acc->{accession_name}}), "check existence of accession names $acc->{accession_name}");
}

my $mech = Test::WWW::Mechanize->new;
$mech->get_ok('http://localhost:3010/ajax/breeders/trial/'.$save->{'trial_id'}.'/design');
my $response = decode_json $mech->content;
#print STDERR Dumper $response;
is(scalar(keys %{$response->{design}}), 11);


#test genotyping project search
$mech->get_ok('http://localhost:3010/ajax/genotyping_data_project/search');
my $response = decode_json $mech->content;

my $search_result = $response->{'data'};
is($search_result->[0]->[1], 'SNP');
is($search_result->[0]->[2], 'genotyping project for test');
is($search_result->[0]->[5], '2022');
is($search_result->[0]->[6], 'Cornell Biotech');
is($search_result->[0]->[7], 'igd');
is($search_result->[0]->[8], '1');
is($search_result->[0]->[9], '11');

#test retrieving genotyping plates in a project
my $plate_info = CXGN::Genotype::GenotypingProject->new({
    bcs_schema => $chado_schema,
    project_id => $genotyping_project_id
});
my ($data, $total_count) = $plate_info->get_plate_info();
is($total_count, 1);
is($data->[0]->{'plate_name'},'test_genotyping_trial_name');
is($data->[0]->{'sample_type'},'DNA');
is($data->[0]->{'plate_format'},'96');
is($data->[0]->{'number_of_samples'}, '11');

#test moving genotyping plate to another project
my $genotyping_project_relationship_cvterm = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'genotyping_project_and_plate_relationship', 'project_relationship');

my $relationship_rs_1 = $chado_schema->resultset("Project::ProjectRelationship")->find ({
    subject_project_id => $genotyping_trial_id,
    type_id => $genotyping_project_relationship_cvterm->cvterm_id()
});
my $project_id_before_moving = $relationship_rs_1->object_project_id();
is($project_id_before_moving, $genotyping_project_id);

my $add_genotyping_project_2 = CXGN::Genotype::StoreGenotypingProject->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    project_name => 'test_genotyping_project_3',
    breeding_program_id => $breeding_program_id,
    project_facility => 'igd',
    data_type => 'snp',
    year => '2022',
    project_description => 'genotyping project for test',
    nd_geolocation_id => $location_id,
    owner_id => 41
});
ok(my $store_return_2 = $add_genotyping_project_2->store_genotyping_project(), "store genotyping project");

my $gp_rs_2 = $chado_schema->resultset('Project::Project')->find({name => 'test_genotyping_project_3'});
my $genotyping_project_id_2 = $gp_rs_2->project_id();
my @genotyping_plate_ids = ($genotyping_trial_id);

my $genotyping_project_obj = CXGN::Genotype::GenotypingProject->new({
    bcs_schema => $chado_schema,
    project_id => $genotyping_project_id_2,
    new_genotyping_plate_list => \@genotyping_plate_ids
});

ok(my $new_associated_project =$genotyping_project_obj->set_project_for_genotyping_plate(), "move plate to new project");

my $relationship_rs_2 = $chado_schema->resultset("Project::ProjectRelationship")->find ({
    subject_project_id => $genotyping_trial_id,
    type_id => $genotyping_project_relationship_cvterm->cvterm_id()
});
my $project_id_after_moving = $relationship_rs_2->object_project_id();
is($project_id_after_moving, $genotyping_project_id_2);


#create westcott trial design_type

my @stock_names_westcott;
for (my $i = 1; $i <= 100; $i++) {
    push(@stock_names_westcott, "test_stock_for_westcott_trial".$i);
}
foreach my $stock_name (@stock_names_westcott) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $stock_name,
	    uniquename => $stock_name,
	    type_id     => $accession_cvterm->cvterm_id,
		 });
};
ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("test_westcott_trial"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names_westcott), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_westcott_check_1("test_stock_for_trial1"), "set check 1");
ok($trial_design->set_westcott_check_2("test_stock_for_trial2"), "set check 2");
ok($trial_design->set_westcott_col(20), "set column number");
ok($trial_design->set_design_type("Westcott"), "set design type");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

$ayt_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'Advanced Yield Trial', 'project_type')->cvterm_id();

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "new_test_trial_name_westcott",
    trial_type=>$ayt_cvterm_id,
    design_type => "Westcott",
    operator => "janedoe"
						    }), "create trial object");

$save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "new_test_trial_name_westcott",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

ok(my $accession_names = $trial_layout->get_accession_names(), "retrieve accession names1");

%stocks = map { $_ => 1 } @stock_names_westcott;
my @accessions;
for (my $i=0; $i<scalar(@stock_names_westcott); $i++){
    foreach my $acc (@$accession_names) {
        if ($acc->{accession_name} eq $stock_names_westcott[$i]){
            push @accessions, $acc->{accession_name};
        }
    }
}
ok(scalar(@accessions) == 100, "check accession names");

#create splitplot trial design_type

my @stock_names_splitplot;
for (my $i = 1; $i <= 100; $i++) {
    push(@stock_names_splitplot, "test_stock_for_splitplot_trial".$i);
}
foreach my $stock_name (@stock_names_splitplot) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $stock_name,
	    uniquename => $stock_name,
	    type_id     => $accession_cvterm->cvterm_id,
		 });
};
ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("test_splitplot_trial_1"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names_splitplot), "set stock list");

# create a treatment here, then delete it at end of test
ok(my $test_treatment = CXGN::Trait::Treatment->new({
    bcs_schema => $chado_schema,
    name => 'test treatment',
    definition => 'A dummy treatment object to run fixture tests.',
    format => 'numeric'
}), 'create a test treatment');

my $exp_treatment_root_term = 'Experimental treatment ontology|EXPERIMENT_TREATMENT:0000000';

ok($test_treatment->store($exp_treatment_root_term), 'store test treatment');

ok(my $test_treatment_id = $test_treatment->cvterm_id(), 'retrieve treatment cvterm id');

ok($trial_design->set_treatments({'test treatment|EXPERIMENT_TREATMENT:0000002' => [0,1]}), "set treatment list");
ok($trial_design->set_number_of_blocks(2), "set number of blocks");
ok($trial_design->set_plot_layout_format("serpentine"), "set serpentine");
ok($trial_design->set_design_type("splitplot"), "set design type");
ok($trial_design->set_num_plants_per_plot(4), "set num plants per plot");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

#print STDERR Dumper $design;

$ayt_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($chado_schema, 'Advanced Yield Trial', 'project_type')->cvterm_id();

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "test_splitplot_trial_1",
    trial_type=>$ayt_cvterm_id,
    design_type => "splitplot",
    trial_has_subplot_entries => 2,
    trial_has_plant_entries => 4,
    operator => "janedoe"
}), "create trial object");

$save = $trial_create->save_trial();
#print STDERR "TRIAL ID = ".$save->{trial_id}."\n";
ok($save->{'trial_id'}, "save trial");

# manually save treatments
my $phenostore_data_hash = {};
my %phenostore_stocks = ();
my %phenostore_treatments = ();

my $time = DateTime->now();
my $pheno_timestamp = $time->ymd()."_".$time->hms();

my $temp_basedir = $fix->config->{tempfiles_subdir};
my $site_basedir = getcwd();
if (! -d "$site_basedir/$temp_basedir/delete_nd_experiment_ids/"){
    mkdir("$site_basedir/$temp_basedir/delete_nd_experiment_ids/");
}
my (undef, $tempfile) = tempfile("$site_basedir/$temp_basedir/delete_nd_experiment_ids/fileXXXX");

ok(my $treatment_design = $design->{'treatments'},'retrieve treatments from design object');
foreach my $unique_treatment (keys(%{$treatment_design->{'treatments'}})) {
    my @treatment_pairs = ($unique_treatment =~ m/\{([^{}]+)\}/g);
    my $treatments = [];
    foreach my $pair (@treatment_pairs) {
        my ($treatment, $value) = $pair =~ m/([^=]+)=(.*)/;
        $phenostore_treatments{$treatment} = 1;
        push @{$treatments}, {
            'treatment' => $treatment,
            'value' => $value
        };
    }
    my $subplots = $treatment_design->{'treatments'}->{$unique_treatment};
    foreach my $treatment (@{$treatments}) {
        foreach my $subplot (@{$subplots}) {
            $phenostore_stocks{$subplot} = 1;
            my $plants = $treatment_design->{'plants'}->{$subplot};
            $phenostore_data_hash->{$subplot}->{$treatment->{'treatment'}} = [
                $treatment->{'value'},
                $pheno_timestamp,
                'janedoe',
                '',
                ''
            ];
            foreach my $plant (@{$plants}) {
                $phenostore_stocks{$plant} = 1;
                $phenostore_data_hash->{$plant}->{$treatment->{'treatment'}} = [
                    $treatment->{'value'},
                    $pheno_timestamp,
                    'janedoe',
                    '',
                    ''
                ];
            }
        }
    }
}

my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({
    basepath => "$temp_basedir",
    dbhost => $fix->config->{dbhost},
    dbuser => $fix->config->{dbuser},
    dbname => $fix->config->{dbname},
    dbpass => $fix->config->{dbpass},
    temp_file_nd_experiment_id => $tempfile,
    bcs_schema => $chado_schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    user_id => 41,
    stock_list => [keys(%phenostore_stocks)],
    trait_list => [keys(%phenostore_treatments)],
    values_hash => $phenostore_data_hash,
    metadata_hash =>{
        archived_file => 'none',
        archived_file_type => 'new trial design with treatments',
        operator => 'janedoe',
        date => $pheno_timestamp
    }
});

my ($verified_warning, $verified_error) = $store_phenotypes->verify();

ok(!$verified_error, 'check no errors on treatment verification');

my ($stored_phenotype_error, $stored_phenotype_success) = $store_phenotypes->store();

ok(!$stored_phenotype_error, 'check no errors on storing treatments');

`rm $tempfile`;

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "test_splitplot_trial_1",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());

my $trial_obj = CXGN::Trial->new({bcs_schema=>$chado_schema, trial_id=>$trial_id});
ok(my $trial_treatments = $trial_obj->get_treatments(), 'retrieve treatments from design');
ok($trial_treatments->[0]->{trait_name} eq 'test treatment|EXPERIMENT_TREATMENT:0000002', 'test correct treatment name'); 
ok($trial_treatments->[0]->{count} > 0, 'test treatments were saved as phenotypes');

ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
						    }), "create trial layout object");

ok(my $accession_names = $trial_layout->get_accession_names(), "retrieve accession names1");

%stocks = map { $_ => 1 } @stock_names_splitplot;
my @accessions;
for (my $i=0; $i<scalar(@stock_names_splitplot); $i++){
    foreach my $acc (@$accession_names) {
        if ($acc->{accession_name} eq $stock_names_splitplot[$i]){
            push @accessions, $acc->{accession_name};
        }
    }
}
ok(scalar(@accessions) == 100, "check accession names");

my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    data_level => 'subplots',
    selected_columns => {"subplot_name"=>1,"plot_name"=>1,"plot_number"=>1,"block_number"=>1}
});
my $output = $trial_layout_download->get_layout_output();
#print STDERR Dumper $output;
is(scalar(@{$output->{output}}), 401);

my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $chado_schema,
    trial_id => $trial_id,
    data_level => 'plants',
    selected_columns => {"plant_name"=>1,"plot_name"=>1,"plot_number"=>1,"block_number"=>1}
});
my $output = $trial_layout_download->get_layout_output();
#print STDERR Dumper $output;
is(scalar(@{$output->{output}}), 801);

eval {$test_treatment->delete()};
ok($@ , 'Check treatment delete is blocked by existing phenotypes');

$fix->clean_up_db();

done_testing();
