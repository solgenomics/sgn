
use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use JSON::Any;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use Spreadsheet::Read;
use Test::WWW::Mechanize;
use CXGN::Cross;
use JSON;
use LWP::UserAgent;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
BEGIN {use_ok('CXGN::Trial::Download');}
BEGIN {use_ok('CXGN::Fieldbook::DownloadTrial');}
BEGIN {use_ok('CXGN::Trial::TrialLayoutDownload');}
BEGIN {use_ok('CXGN::Trial');}

ok(my $schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
ok(my $metadata_schema = $fix->metadata_schema);
ok(my $dbh = $fix->dbh);


# create crosses and family_names for trials
my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "cross", "stock_type")->cvterm_id();
my $family_name_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "family_name", "stock_type")->cvterm_id();

my @cross_ids;
for (my $i = 1; $i <= 5; $i++) {
    push(@cross_ids, "cross_for_trial".$i);
}

my @family_names;
for (my $i = 1; $i <= 5; $i++) {
    push(@family_names, "family_name_for_trial".$i);
}

ok(my $organism = $schema->resultset("Organism::Organism")
    ->find_or_create( {
       genus => 'Test_genus',
       species => 'Test_genus test_species',
	}, ));

foreach my $cross_id (@cross_ids) {
    my $cross_for_trial = $schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $cross_id,
	    uniquename => $cross_id,
	    type_id     => $cross_type_id,
    });
};

foreach my $family_name (@family_names) {
    my $family_name_for_trial = $schema->resultset('Stock::Stock')
	->create({
	    organism_id => $organism->organism_id,
	    name       => $family_name,
	    uniquename => $family_name,
	    type_id     => $family_name_type_id,
	});
};

#add accession stock type for testing mixed types
push(@cross_ids, 'UG120001');

# create trial with cross stock type
ok(my $cross_trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($cross_trial_design->set_trial_name("cross_to_trial1"), "set trial name");
ok($cross_trial_design->set_stock_list(\@cross_ids), "set stock list");
ok($cross_trial_design->set_plot_start_number(1), "set plot start number");
ok($cross_trial_design->set_plot_number_increment(1), "set plot increment");
ok($cross_trial_design->set_number_of_blocks(2), "set block number");
ok($cross_trial_design->set_design_type("RCBD"), "set design type");
ok($cross_trial_design->calculate_design(), "calculate design");
ok(my $cross_design = $cross_trial_design->get_design(), "retrieve design");

my $preliminary_trial_cvterm_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'Preliminary Yield Trial', 'project_type')->cvterm_id();

ok(my $crosses_trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema,
    dbh => $dbh,
    owner_id => 41,
    design => $cross_design,
    program => "test",
    trial_year => "2020",
    trial_description => "test description",
    trial_location => "test_location",
    trial_name => "cross_to_trial1",
    trial_type=>$preliminary_trial_cvterm_id,
    design_type => "RCBD",
    operator => "janedoe",
    trial_stock_type => "cross"
}), "create trial object");

my $crosses_trial_save = $crosses_trial_create->save_trial();
ok($crosses_trial_save->{'trial_id'}, "save trial");


# retrieving cross trial and design info
ok(my $crosses_trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $schema,
    trial_name => "cross_to_trial1",
}), "create trial lookup object");
ok(my $crosses_trial = $crosses_trial_lookup->get_trial());
ok(my $cross_trial_id = $crosses_trial->project_id());

print STDERR "########## CREATING NEW TRIAL LAYOUT OBJECT \n";
my $cross_trial_layout;
ok($cross_trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $schema,
    trial_id => $cross_trial_id,
    experiment_type => 'field_layout'
}), "create trial layout object for cross trial");

my $cross_trial_design = $cross_trial_layout->get_design();
my @cross_plot_nums;
my @crosses;
my @cross_block_nums;
my @cross_plot_names;

print STDERR "CROSS LAYOUT = ".Dumper($cross_trial_design);

# note:cross and family_name stock types use the same accession_name key as accession stock type in trial design
foreach my $cross_plot_num (keys %$cross_trial_design) {
    push @cross_plot_nums, $cross_plot_num;
    push @crosses, $cross_trial_design->{$cross_plot_num}->{'accession_name'};
    push @cross_block_nums, $cross_trial_design->{$cross_plot_num}->{'block_number'};
    push @cross_plot_names, $cross_trial_design->{$cross_plot_num}->{'plot_name'};

}
@cross_plot_nums = sort @cross_plot_nums;
@crosses = sort @crosses;
@cross_block_nums = sort @cross_block_nums;

#is_deeply(\@cross_plot_nums, [
#        '1001',
#        '1002',
#        '1003',
#        '1004',
#        '1005',
#        '2001',
#        '2002',
#        '2003',
#        '2004',
#        '2005'
#    ], "check cross plot numbers");

is_deeply(\@crosses, [
        'UG120001',
        'UG120001',
        'cross_for_trial1',
        'cross_for_trial1',
        'cross_for_trial2',
        'cross_for_trial2',
        'cross_for_trial3',
        'cross_for_trial3',
        'cross_for_trial4',
        'cross_for_trial4',
        'cross_for_trial5',
        'cross_for_trial5'
    ], "check cross unique ids");

is_deeply(\@cross_block_nums, [
        '1',
        '1',
        '1',
        '1',
        '1',
        '1',
        '2',
        '2',
        '2',
        '2',
        '2',
        '2'
    ], "check cross block numbers");

is(scalar@cross_plot_names, 12);

my $cross_trial_type = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $cross_trial_id });
my $cross_trial_stock_type = $cross_trial_type->get_trial_stock_type();
is($cross_trial_stock_type, 'cross');

#add accession for testing mixed stock types
push (@family_names, 'UG120001');
# create trial with family_name stock type
my $fam_trial_design;
ok($fam_trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($fam_trial_design->set_trial_name("family_name_to_trial1"), "set trial name");
ok($fam_trial_design->set_stock_list(\@family_names), "set stock list");
ok($fam_trial_design->set_plot_start_number(1), "set plot start number");
ok($fam_trial_design->set_plot_number_increment(1), "set plot increment");
ok($fam_trial_design->set_number_of_reps(2), "set rep number");
ok($fam_trial_design->set_design_type("CRD"), "set design type");
ok($fam_trial_design->calculate_design(), "calculate design");

my $fam_design;
ok($fam_design = $fam_trial_design->get_design(), "retrieve design");

my $fam_trial_create;
ok($fam_trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema,
    dbh => $dbh,
    owner_id => 41,
    design => $fam_design,
    program => "test",
    trial_year => "2020",
    trial_description => "test description",
    trial_location => "test_location",
    trial_name => "family_name_to_trial1",
    trial_type=>$preliminary_trial_cvterm_id,
    design_type => "CRD",
    operator => "janedoe",
    trial_stock_type => "family_name"
}), "create trial object");

my $fam_save = $fam_trial_create->save_trial();
ok($fam_save->{'trial_id'}, "save trial");


# retrieving family_name trial with design info
ok(my $fam_trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $schema,
    trial_name => "family_name_to_trial1",
}), "create trial lookup object");
ok(my $fam_trial = $fam_trial_lookup->get_trial());
ok(my $fam_trial_id = $fam_trial->project_id());
ok(my $fam_trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $schema,
    trial_id => $fam_trial_id,
    experiment_type => 'field_layout'
}), "create trial layout object for family trial");

my $fam_trial_design = $fam_trial_layout->get_design();
my @fam_plot_nums;
my @family_names;
my @fam_rep_nums;
my @fam_plot_names;

print STDERR "FAMILY TRIAL DESIGN: ".Dumper($fam_trial_design);
# note:cross and family_name stock types use the same accession_name key as accession stock type in trial design
foreach my $fam_plot_num (keys %$fam_trial_design) {
    push @fam_plot_nums, $fam_plot_num;
    push @family_names, $fam_trial_design->{$fam_plot_num}->{'accession_name'};
    push @fam_rep_nums, $fam_trial_design->{$fam_plot_num}->{'rep_number'};
    push @fam_plot_names, $fam_trial_design->{$fam_plot_num}->{'plot_name'};
}
@fam_plot_nums = sort @fam_plot_nums;
@family_names = sort @family_names;
@fam_rep_nums = sort @fam_rep_nums;

#is_deeply(\@fam_plot_nums, [
#        '1001',
#        '1002',
#        '1003',
#        '1004',
#        '1005',
#        '1006',
#        '1007',
#        '1008',
#        '1009',
#        '1010'
#    ], "check family_name plot numbers");

is_deeply(\@family_names, [
        'UG120001',
        'UG120001',
        'family_name_for_trial1',
        'family_name_for_trial1',
        'family_name_for_trial2',
        'family_name_for_trial2',
        'family_name_for_trial3',
        'family_name_for_trial3',
        'family_name_for_trial4',
        'family_name_for_trial4',
        'family_name_for_trial5',
        'family_name_for_trial5'
    ], "check family names");

is_deeply(\@fam_rep_nums, [
        '1',
        '1',
        '1',
        '1',
        '1',
        '1',
        '2',
        '2',
        '2',
        '2',
        '2',
        '2'
    ], "check fam rep numbers");

is(scalar@fam_plot_names, 12);

my $fam_trial_type = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $fam_trial_id });
my $fam_trial_stock_type = $fam_trial_type->get_trial_stock_type();
is($fam_trial_stock_type, 'family_name');


# create cross trial Fieldbook
my $cross_fieldbook_tempfile = "/tmp/test_create_cross_trial_fieldbook.xls";

my $cross_fieldbook = CXGN::Fieldbook::DownloadTrial->new({
    bcs_schema => $schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $cross_trial_id,
    tempfile => $cross_fieldbook_tempfile,
    archive_path => $fix->config->{archive_path},
    user_id => 41,
    user_name => "janedoe",
    data_level => 'plots',
    selected_columns=> {'plot_name'=>1, 'plot_id'=>1, 'plot_number'=>1 ,'block_number'=>1,,'accession_name'=>1},
    trial_stock_type => 'cross'
});

my $create_fieldbook_return = $cross_fieldbook->download();
ok($create_fieldbook_return, "check that download trial fieldbook returns something.");

my $contents = ReadData $create_fieldbook_return->{'file'};
#print STDERR Dumper @contents->[0]->[0];
is($contents->[0]->{'type'}, 'xls', "check that type of file is correct");

my $columns = $contents->[1]->{'cell'};
ok(scalar(@$columns) == 6, "check number of col in created file.");
my @field_book_columns = @$columns;
is($field_book_columns[1][1], 'plot_name');
is($field_book_columns[2][1], 'plot_id');
is($field_book_columns[3][1], 'cross_unique_id');
is($field_book_columns[4][1], 'plot_number');
is($field_book_columns[5][1], 'block_number');
print STDERR "FIELDBOOK COLUMNS =".Dumper($columns)."\n";


# create family_name trial Fieldbook
my $family_fieldbook_tempfile = "/tmp/test_create_family_trial_fieldbook.xls";

my $family_fieldbook = CXGN::Fieldbook::DownloadTrial->new({
    bcs_schema => $schema,
    metadata_schema => $metadata_schema,
    phenome_schema => $phenome_schema,
    trial_id => $fam_trial_id,
    tempfile => $family_fieldbook_tempfile,
    archive_path => $fix->config->{archive_path},
    user_id => 41,
    user_name => "janedoe",
    data_level => 'plots',
    selected_columns=> {'plot_name'=>1, 'plot_id'=>1, 'plot_number'=>1 ,'rep_number'=>1,,'accession_name'=>1},
    trial_stock_type => 'family_name'
});

my $create_family_fieldbook_return = $family_fieldbook->download();
ok($create_family_fieldbook_return, "check that download trial fieldbook returns something.");

my $family_contents = ReadData $create_family_fieldbook_return->{'file'};
#print STDERR Dumper @contents->[0]->[0];
is($family_contents->[0]->{'type'}, 'xls', "check that type of file is correct");

my $family_columns = $family_contents->[1]->{'cell'};
ok(scalar(@$family_columns) == 6, "check number of col in created file.");
my @family_field_book_columns = @$family_columns;
is($family_field_book_columns[1][1], 'plot_name');
is($family_field_book_columns[2][1], 'plot_id');
is($family_field_book_columns[3][1], 'family_name');
is($family_field_book_columns[4][1], 'plot_number');
is($family_field_book_columns[5][1], 'rep_number');
print STDERR "FAMILY FIELDBOOK COLUMNS =".Dumper($family_columns)."\n";


#create westcott trial design_type using cross_unique_ids

my @cross_unique_ids_westcott;
for (my $i = 1; $i <= 100; $i++) {
    push(@cross_unique_ids_westcott, "cross_for_westcott_trial".$i);
}

foreach my $cross_unique_id (@cross_unique_ids_westcott) {
    my $cross_stock = $schema->resultset('Stock::Stock')->create({
	    organism_id => $organism->organism_id,
	    name       => $cross_unique_id,
	    uniquename => $cross_unique_id,
	    type_id     => $cross_type_id,
    });
};

my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();

my @accessions_westcott;
for (my $i = 1; $i <= 2; $i++) {
    push @accessions_westcott, "check_accession_for_westcott_trial".$i;
}

print STDERR "ACCESSIONS WESTCOTT: ".Dumper(\@accessions_westcott);

foreach my $accession (@accessions_westcott) {
    my $accession_stock = $schema->resultset('Stock::Stock')->create(
	{
	    organism_id => $organism->organism_id,
	    name        => $accession,
	    uniquename  => $accession,
	    #type_id     => $accession_type_id,
	    type_id     => $cross_type_id,
	});
    print STDERR "Created accession $accession with type_id $accession_type_id\n";
}

ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");

ok($trial_design->set_trial_name("cross_westcott_trial"), "set trial name");
ok($trial_design->set_stock_list(\@cross_unique_ids_westcott), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_westcott_check_1("check_accession_for_westcott_trial1"), "set check 1");
ok($trial_design->set_westcott_check_2("check_accession_for_westcott_trial2"), "set check 2");
ok($trial_design->set_westcott_col(20), "set column number");
ok($trial_design->set_design_type("Westcott"), "set design type");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema,
    dbh => $dbh,
    owner_id => 41,
    design => $design,
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location",
    trial_name => "cross_westcott_trial",
    trial_type=>$preliminary_trial_cvterm_id,
    design_type => "Westcott",
    operator => "janedoe",
    trial_stock_type => 'cross'
}), "create trial object");

my $save = $trial_create->save_trial();
ok($save->{'trial_id'}, "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $schema,
    trial_name => "cross_westcott_trial",
}), "create trial lookup object");

ok(my $trial = $trial_lookup->get_trial());ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $schema,
    trial_id => $trial_id,
    experiment_type => 'field_layout'
}), "create trial layout object for westcott trial");

ok(my $stock_names = $trial_layout->get_accession_names(), "retrieve cross_unique_ids");

print STDERR "STOCK NAMES IN WESTCOTT = ".Dumper($stock_names);

my %stocks = map { $_ => 1 } @cross_unique_ids_westcott;
my @crosses;
for (my $i=0; $i<scalar(@cross_unique_ids_westcott); $i++){
    foreach my $cross (@$stock_names) {
        if ($cross->{accession_name} eq $cross_unique_ids_westcott[$i]){
            push @crosses, $cross->{accession_name};
        }
    }
}
ok(scalar(@crosses) == 100, "check cross unique id");

my $mech = Test::WWW::Mechanize->new;
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username"=> "janedoe", "password"=> "secretpw", "grant_type"=> "password" ]);
my $response = decode_json $mech->content;
is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
my $sgn_session_id = $response->{access_token};
print STDERR $sgn_session_id."\n";

#test deleting a cross using in trial
my $cross_in_trial_id = $schema->resultset("Stock::Stock")->find({name=>'cross_for_trial1'})->stock_id;
$mech->post_ok('http://localhost:3010/ajax/cross/delete', [ 'cross_id' => $cross_in_trial_id]);
$response = decode_json $mech->content;
is_deeply($response, {'error' => 'An error occurred attempting to delete a cross. (Cross has associated trial: cross_to_trial1. Cannot delete.
)'});

done_testing();
