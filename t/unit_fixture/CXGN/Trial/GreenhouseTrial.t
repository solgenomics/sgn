
use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use JSON::Any;
use Data::Dumper;
use Test::WWW::Mechanize;
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


# create accession names for greenhouse trial
my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, "accession", "stock_type")->cvterm_id();

my @greenhouse_accessions;
for (my $i = 1; $i <= 6; $i++) {
    push(@greenhouse_accessions, "accession_for_greenhouse" . $i);
}

ok(my $organism = $schema->resultset("Organism::Organism")
    ->find_or_create({
    genus   => 'Test_genus',
    species => 'Test_genus test_species',
},));

foreach my $accession_name (@greenhouse_accessions) {
    my $accessions = $schema->resultset('Stock::Stock')->create({
        organism_id => $organism->organism_id,
        name        => $accession_name,
        uniquename  => $accession_name,
        type_id     => $accession_type_id,
    });
};

my @greenhouse_num_plants = ('1','1','1','1','1','1');

ok(my $greenhouse_trial = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($greenhouse_trial->set_trial_name("greenhouse_1"), "set trial name");
ok($greenhouse_trial->set_stock_list(\@greenhouse_accessions), "set stock list");
ok($greenhouse_trial->set_plot_start_number(1), "set plot start number");
ok($greenhouse_trial->set_plot_number_increment(1), "set plot increment");
ok($greenhouse_trial->set_number_of_blocks(1), "set block number");
ok($greenhouse_trial->set_design_type("greenhouse"), "set design type");
ok($greenhouse_trial->set_greenhouse_num_plants(\@greenhouse_num_plants), "set number of plants");

ok($greenhouse_trial->calculate_design(), "calculate design");
ok(my $greenhouse_design = $greenhouse_trial->get_design(), "retrieve design");

ok(my $greenhouse_trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema      => $schema,
    dbh               => $dbh,
    owner_id          => 41,
    design            => $greenhouse_design,
    program           => "test",
    trial_year        => "2025",
    trial_description => "test description",
    trial_location    => "test_location",
    trial_name        => "greenhouse_1",
    trial_type        => '',
    design_type       => "greenhouse",
    operator          => "janedoe",
    trial_stock_type  => "accession"
}), "create trial object");

my $greenhouse_trial_save = $greenhouse_trial_create->save_trial();
ok($greenhouse_trial_save->{'trial_id'}, "save trial");


ok(my $greenhouse_trial_lookup = CXGN::Trial::TrialLookup->new({
    schema     => $schema,
    trial_name => "greenhouse_1",
}), "create trial lookup object");
ok(my $greenhouse_trial = $greenhouse_trial_lookup->get_trial());
ok(my $greenhouse_trial_id = $greenhouse_trial->project_id());

my $greenhouse_trial_layout;
ok($greenhouse_trial_layout = CXGN::Trial::TrialLayout->new({
    schema          => $schema,
    trial_id        => $greenhouse_trial_id,
    experiment_type => 'field_layout'
}), "create trial layout object for greenhouse trial");

my $greenhouse_trial_design = $greenhouse_trial_layout->get_design();
my @plot_nums;
my @accessions;
my @block_nums;
my @plot_names;
print STDERR "LAYOUT = " . Dumper($greenhouse_trial_design);

foreach my $plot_num (keys %$greenhouse_trial_design) {
    push @plot_nums, $plot_num;
    push @accessions, $greenhouse_trial_design->{$plot_num}->{'accession_name'};
    push @block_nums, $greenhouse_trial_design->{$plot_num}->{'block_number'};
    push @plot_names, $greenhouse_trial_design->{$plot_num}->{'plot_name'};
}

@plot_nums = sort @plot_nums;
@accessions = sort @accessions;

is_deeply(\@plot_nums, [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
], "check plot numbers");

is_deeply(\@accessions, [
    'accession_for_greenhouse1',
    'accession_for_greenhouse2',
    'accession_for_greenhouse3',
    'accession_for_greenhouse4',
    'accession_for_greenhouse5',
    'accession_for_greenhouse6',
], "check accessions");

is_deeply(\@block_nums, [
    '1',
    '1',
    '1',
    '1',
    '1',
    '1',
], "check greenhouse block numbers");

is(scalar @plot_names, 6);

$fix->clean_up_db();

done_testing();
