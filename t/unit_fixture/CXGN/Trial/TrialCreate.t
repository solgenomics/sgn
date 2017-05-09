
use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use Data::Dumper;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
BEGIN {use_ok('CXGN::Trial'); }

ok(my $chado_schema = $fix->bcs_schema);
ok(my $phenome_schema = $fix->phenome_schema);
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

#create stocks for genotyping trial
my @genotyping_stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@genotyping_stock_names, "test_stock_for_genotyping_trial".$i);
}


ok(my $organism = $chado_schema->resultset("Organism::Organism")
   ->find_or_create( 
       {
	   genus => 'Test_genus',
	   species => 'Test_genus test_species',
       })
    );

# create some test stocks
foreach my $stock_name (@stock_names) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
	->create(
	{
	    organism_id => $organism->organism_id,
	    name       => $stock_name,
	    uniquename => $stock_name,
	    type_id     => $accession_cvterm->cvterm_id,
	});
}

# create some genotyping test stocks
foreach my $stock_name (@genotyping_stock_names) {
    my $accession_stock = $chado_schema->resultset('Stock::Stock')
	->create(
	{
	    organism_id => $organism->organism_id,
	    name       => $stock_name,
	    uniquename => $stock_name,
	    type_id     => $accession_cvterm->cvterm_id,
	});
}

ok(my $trial_design = CXGN::Trial::TrialDesign->new(), "create trial design object");
ok($trial_design->set_trial_name("test_trial"), "set trial name");
ok($trial_design->set_stock_list(\@stock_names), "set stock list");
ok($trial_design->set_plot_start_number(1), "set plot start number");
ok($trial_design->set_plot_number_increment(1), "set plot increment");
ok($trial_design->set_number_of_blocks(2), "set block number");
ok($trial_design->set_design_type("RCBD"), "set design type");
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

ok(my $trial_create = CXGN::Trial::TrialCreate->new(
       {
	   chado_schema => $chado_schema,
	   dbh => $dbh,
	   user_name => "johndoe", #not implemented
	   design => $design,	
	   program => "test",
	   trial_year => "2015",
	   trial_description => "test description",
	   trial_location => "test_location_for_trial",
	   trial_name => "new_test_trial_name",
	   design_type => "RCBD",
       }), "create trial object");

ok($trial_create->save_trial(), "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new(
       {
	   schema => $chado_schema,
	   trial_name => "new_test_trial_name",
       }), "create trial lookup object");

ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new(
       {
	   schema => $chado_schema,
	   trial_id => $trial_id,	   
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
ok($trial_design->calculate_design(), "calculate design");
ok(my $design = $trial_design->get_design(), "retrieve design");

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    dbh => $dbh,
    user_name => "johndoe", #not implemented
    design => $design,	
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "new_test_trial_name_single",
    design_type => "RCBD",
						    }), "create trial object");
ok($trial_create->save_trial(), "save trial");

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "new_test_trial_name_single",
						    }), "create trial lookup object");
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,

						    }), "create trial layout object");

ok(my $accession_names = $trial_layout->get_accession_names(), "retrieve accession names2");

my %stocks = map { $_ => 1 } @stock_names;

foreach my $acc (@$accession_names) {
    ok(exists($stocks{$acc->{accession_name}}), "check accession names $acc->{accession_name}");
}



#make design for genotyping
my %geno_design;

for (my $i = 0; $i < scalar(@genotyping_stock_names); $i++) {
    my %plot_info;    
    $plot_info{'stock_name'} = @genotyping_stock_names[$i];
    $plot_info{'plot_name'} = @genotyping_stock_names[$i]."_test_trial_name_".$i;
    $geno_design{$i+1} = \%plot_info;
}

ok(my $genotyping_trial_create = CXGN::Trial::TrialCreate->new(
       {
	   chado_schema => $chado_schema,
	   dbh => $dbh,
	   trial_class => "genotyping",
	   user_name => "johndoe", #not implemented
	   design => \%geno_design,	
	   program => "test",
	   trial_year => "2015",
	   trial_description => "test description",
	   trial_location => "test_location_for_trial",
	   trial_name => "test_genotyping_trial_name",
	   design_type => "genotyping_plate",
       }), "create genotyping trial");

ok($genotyping_trial_create->save_trial(), "save genotyping trial");

ok(my $genotyping_trial_lookup = CXGN::Trial::TrialLookup->new( 
       {
	   schema => $chado_schema,
	   trial_name => "test_genotyping_trial_name",
       }), "lookup genotyping trial");

ok(my $genotyping_trial = $genotyping_trial_lookup->get_trial(), "retrieve genotyping trial");
ok(my $genotyping_trial_id = $genotyping_trial->project_id(), "retrive genotyping trial id");

ok(my $genotyping_trial_layout = CXGN::Trial::TrialLayout->new(
       {
	   schema => $chado_schema,
	   trial_id => $genotyping_trial_id,	   
       }), "create trial layout object for genotyping trial");

ok(my $genotyping_accession_names = $genotyping_trial_layout->get_accession_names(), "retrieve accession names3");
my %genotyping_stocks = map { $_ => 1 } @genotyping_stock_names;
foreach my $acc (@$genotyping_accession_names) { 
    ok(exists($genotyping_stocks{$acc->{accession_name}}), "check existence of accession names $acc->{accession_name}");
}

# make design for accession_average
#
#create stocks for accession_average trial
my @avg_stock_names;
for (my $i = 1; $i <= 10; $i++) {
    push(@avg_stock_names, "test_stock_for_avg_trial".$i);
}

my %acc_avg_design;

for (my $i = 0; $i < scalar(@avg_stock_names); $i++) {
    my %plot_info;
    
    $plot_info{'stock_name'} = @avg_stock_names[$i];
    $plot_info{'plot_name'} = @avg_stock_names[$i]."_test_trial_name_".$i;
    $acc_avg_design{$i+1} = \%plot_info;
}

# ok(my $avg_trial_create = CXGN::Trial::TrialCreate->new(
#        {
# 	   chado_schema => $chado_schema,
# 	   dbh => $dbh,
# 	   trial_class => "averaged_trial",
# 	   user_name => "johndoe", #not implemented
# 	   design => \%acc_avg_design,	
# 	   program => "test",
# 	   trial_year => "2015",
# 	   trial_description => "test description",
# 	   trial_location => "test_location_for_trial",
# 	   trial_name => "test_avg_trial_name",
# 	   design_type => "mean",
#        }), "create avg trial");

#ok($avg_trial_create->save_trial(), "save averaged accession trial");

ok(my $avg_trial_lookup = CXGN::Trial::TrialLookup->new(
       {
	   schema => $chado_schema,
	   trial_name => "new_test_trial_name_single",
       }), "lookup avg trial");

ok(my $avg_trial = $avg_trial_lookup->get_trial(), "retrieve avg trial");
ok(my $avg_trial_id = $avg_trial->project_id(), "retrieve avg trial id");

ok(my $avg_trial_design = CXGN::Trial::TrialDesign->new(
       {
	   schema => $chado_schema,
	   trial_id => $avg_trial_id,
	   design_type => 'averaged_trial',
       }), "create trial layout object for accession average trial");


my $t = CXGN::Trial->new({ bcs_schema => $chado_schema, trial_id => $avg_trial_id });

print STDERR Dumper($t->get_accessions());

$avg_trial_design->set_stock_list( [ map { $_->{accession_name} } @{$t->get_accessions()} ] );

ok(my @avg_accession_names = $avg_trial_design->get_stock_list(), "retrieve accession names");

print STDERR Dumper(\@avg_accession_names);

my $design_hash = $avg_trial_design->get_design();

my $trial_create = CXGN::Trial::TrialCreate->new(
    {
	chado_schema => $chado_schema,
	dbh => $dbh,
#	user_name => $user_name, #not implemented,
	design_type => '',
	design => $design_hash,
	program => $t->get_breeding_program(),
	trial_year => $t->get_year(),
	trial_description => 'averaged trial',
	trial_location => $t->get_location()->[1],
	trial_name => 'averaged_trial_',
	trial_class => 'averaged_trial',
    });

$trial_create->save_trial();

done_testing();
