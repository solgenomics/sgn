use strict;
use Test::More qw | no_plan |;
use lib 't/lib';
use SGN::Test::Fixture;

my $fix = SGN::Test::Fixture->new();

is(ref($fix->config()), "HASH", 'hashref check');

BEGIN {use_ok('CXGN::Trial::TrialCreate');}
BEGIN {use_ok('CXGN::Trial::TrialLayout');}
BEGIN {use_ok('CXGN::Trial::TrialDesign');}
BEGIN {use_ok('CXGN::Trial::TrialLookup');}
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
       cv     => 'stock type',
       db     => 'null',
       dbxref => 'accession',
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


ok(my $trial_design = CXGN::Trial::TrialDesign->new());
ok($trial_design->set_trial_name("test_trial"));
ok($trial_design->set_stock_list(\@stock_names));
ok($trial_design->set_plot_start_number(1));
ok($trial_design->set_plot_number_increment(1));
ok($trial_design->set_number_of_blocks(2));
ok($trial_design->set_design_type("RCBD"));
ok($trial_design->calculate_design());
ok(my $design = $trial_design->get_design());

ok(my $trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    phenome_schema => $phenome_schema,
    dbh => $dbh,
    user_name => "johndoe",
    design => $design,	
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "new_test_trial_name",
    design_type => "RCBD",
						    }));
ok($trial_create->save_trial());

ok(my $trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "new_test_trial_name",
						    }));
ok(my $trial = $trial_lookup->get_trial());
ok(my $trial_id = $trial->project_id());
ok(my $trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $trial_id,

						    }));

ok(my $accession_names = $trial_layout->get_accession_names());

my %stocks = map { $_ => 1 } @stock_names;
ok(exists($stocks{@$accession_names[0]}));


#make design for genotyping
my %geno_design;

  for (my $i = 0; $i < scalar(@genotyping_stock_names); $i++) {
    my %plot_info;
    
    #a
    $plot_info{'stock_name'} = @genotyping_stock_names[$i];
    #$plot_info{'block_number'} = $block_numbers[$i];
    #$plot_info{'plot_name'} = $converted_plot_numbers[$i];
    $plot_info{'plot_name'} = @genotyping_stock_names[$i]."_test_trial_name_".$i;
    $geno_design{$i+1} = \%plot_info;
  }

ok(my $genotyping_trial_create = CXGN::Trial::TrialCreate->new({
    chado_schema => $chado_schema,
    phenome_schema => $phenome_schema,
    dbh => $dbh,
    is_genotyping => 1,
    user_name => "johndoe",
    design => \%geno_design,	
    program => "test",
    trial_year => "2015",
    trial_description => "test description",
    trial_location => "test_location_for_trial",
    trial_name => "test_genotyping_trial_name",
    design_type => "Genotyping",
							       }));

ok($genotyping_trial_create->save_trial());

ok(my $genotyping_trial_lookup = CXGN::Trial::TrialLookup->new({
    schema => $chado_schema,
    trial_name => "test_genotyping_trial_name",
						    }));
ok(my $genotyping_trial = $genotyping_trial_lookup->get_trial());
ok(my $genotyping_trial_id = $genotyping_trial->project_id());
ok(my $genotyping_trial_layout = CXGN::Trial::TrialLayout->new({
    schema => $chado_schema,
    trial_id => $genotyping_trial_id,

						    }));
ok(my $genotyping_accession_names = $genotyping_trial_layout->get_accession_names());
my %genotyping_stocks = map { $_ => 1 } @genotyping_stock_names;
ok(exists($genotyping_stocks{@$genotyping_accession_names[0]}));
