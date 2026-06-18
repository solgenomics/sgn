use strict;
use warnings;
use lib 't/lib';

use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use LWP::UserAgent;
use Selenium::Waiter qw(wait_until);
use Selenium::Remote::WDKeys 'KEYS';

my $d = SGN::Test::WWW::WebDriver->new();
my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

sub get_cvterm_id {
    my ($name) = @_;
    my $term ||= $schema->resultset("Cv::Cvterm")->search({ 'me.name' => $name })->first;
    die "Required CVTerm '$name' not found in database fixture" unless $term;
    return $term->cvterm_id();
}

# Resolve CVTerm IDs for stocks and relationships
my $breeding_program_type_id = get_cvterm_id('breeding_program');
my $crossing_trial_type_id = get_cvterm_id('crossing_trial');
my $bp_trial_rel_type_id = get_cvterm_id('breeding_program_trial_relationship');
my $cross_experiment_type_id = get_cvterm_id('cross_experiment');
my $field_layout_type_id = get_cvterm_id('field_layout');
my $project_year_type_id = get_cvterm_id('project year');
my $project_location_type_id = get_cvterm_id('project location');

my $accession_type_id = get_cvterm_id('accession');
my $cross_type_id = get_cvterm_id('cross');
my $plot_type_id = get_cvterm_id('plot');
my $population_type_id = get_cvterm_id('population');
my $female_parent_rel_type_id = get_cvterm_id('female_parent');
my $male_parent_rel_type_id = get_cvterm_id('male_parent');
my $offspring_of_rel_type_id = get_cvterm_id('offspring_of');
my $plot_of_rel_type_id = get_cvterm_id('plot_of');

# Create Breeding Program and Crossing Trial
my $breeding_program = $schema->resultset("Project::Project")->find_or_create({ name => 'Test Breeding Program', description => 'Test Breeding Program', type_id => $breeding_program_type_id });
my $crossing_trial = $schema->resultset("Project::Project")->find_or_create({ name => 'Test Crossing Trial', description => 'Test Crossing Trial', type_id => $crossing_trial_type_id });
$schema->resultset("Project::ProjectRelationship")->find_or_create({ subject_project_id => $crossing_trial->project_id, object_project_id => $breeding_program->project_id, type_id => $bp_trial_rel_type_id });

my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")->first();
my $nd_geolocation_id = $geolocation ? $geolocation->nd_geolocation_id() : 1;

# Set trial metadata (year and location are required for many Breedbase search logic and views)
$schema->resultset("Project::Projectprop")->find_or_create({ project_id => $crossing_trial->project_id, type_id => $project_year_type_id, value => '2024' });
$schema->resultset("Project::Projectprop")->find_or_create({ project_id => $crossing_trial->project_id, type_id => $project_location_type_id, value => $nd_geolocation_id });

# Get an organism ID to associate with the new test stocks
my $organism = $schema->resultset("Organism::Organism")->first()
    or die "No organism found in database fixture";
my $organism_id = $organism->organism_id();

my %parents;
my @parent_definitions = (
    { name => 'CrossesTestFemale1', type => $accession_type_id },
    { name => 'CrossesTestMale1',   type => $accession_type_id },
    { name => 'CrossesTestMale2',   type => $accession_type_id },
    { name => 'CrossesTestMale3',   type => $accession_type_id },
    { name => 'CrossesTestMale4',   type => $population_type_id },
    { name => 'CrossesTestMale5',   type => $population_type_id },
);

foreach my $p_def (@parent_definitions) {
    my $p_stock = $schema->resultset("Stock::Stock")->find_or_create({
        uniquename => $p_def->{name},
        name => $p_def->{name},
        type_id => $p_def->{type},
        organism_id => $organism_id,
    });
    $parents{$p_def->{name}} = $p_stock->stock_id;
}

# Define the crosses to create
my @crosses_to_create = (
    { name => 'CrossesTestCross1', female => 'CrossesTestFemale1', male => 'CrossesTestMale1', type => 'biparental' },
    { name => 'CrossesTestCross2', female => 'CrossesTestFemale1', male => 'CrossesTestMale2', type => 'biparental' },
    { name => 'CrossesTestCross3', female => 'CrossesTestFemale1', male => 'CrossesTestMale3', type => 'biparental' },
    { name => 'CrossesTestCross4', female => 'CrossesTestFemale1', male => 'CrossesTestFemale1', type => 'self' },
    { name => 'CrossesTestCross5', female => 'CrossesTestFemale1', male => 'CrossesTestMale4', type => 'open' },
    { name => 'CrossesTestCross6', female => 'CrossesTestFemale1', male => 'CrossesTestMale5', type => 'open' },
);

foreach my $c_info (@crosses_to_create) {
    my $cross_stock = $schema->resultset("Stock::Stock")->find_or_create({
        uniquename => $c_info->{name},
        name => $c_info->{name},
        type_id => $cross_type_id,
        organism_id => $organism_id,
    });

    # Link cross to experiment
    my $nd_experiment = $schema->resultset("NaturalDiversity::NdExperiment")->create({ nd_geolocation_id => $nd_geolocation_id, type_id => $cross_experiment_type_id });
    $nd_experiment->create_related('nd_experiment_stocks', { stock_id => $cross_stock->stock_id, type_id => $cross_experiment_type_id });
    $nd_experiment->create_related('nd_experiment_projects', { project_id => $crossing_trial->project_id });

    $schema->resultset("Stock::StockRelationship")->find_or_create({ subject_id => $parents{$c_info->{female}}, object_id => $cross_stock->stock_id, type_id => $female_parent_rel_type_id, value => $c_info->{type} });
    $schema->resultset("Stock::StockRelationship")->find_or_create({ subject_id => $parents{$c_info->{male}}, object_id => $cross_stock->stock_id, type_id => $male_parent_rel_type_id }) if $c_info->{male};

    # Create one or more progeny accessions for each mock cross
    my @progeny_suffixes = ('_progeny');
    push @progeny_suffixes, '_progeny_sibling' if $c_info->{name} eq 'CrossesTestCross1'; # Add a second progeny to CrossesTestCross1

    foreach my $suffix (@progeny_suffixes) {
        my $progeny_name = $c_info->{name} . $suffix;
        my $progeny_stock = $schema->resultset("Stock::Stock")->find_or_create({
            uniquename => $progeny_name,
            name => $progeny_name,
            type_id => $accession_type_id,
            organism_id => $organism_id,
        });

        # Create a plot for the progeny and link it to the trial (required for materialized views used in many progeny grids)
        my $progeny_plot_name = $progeny_name . "_plot";
        my $progeny_plot = $schema->resultset("Stock::Stock")->find_or_create({
            uniquename => $progeny_plot_name,
            name => $progeny_plot_name,
            type_id => $plot_type_id,
            organism_id => $organism_id,
        });
        $schema->resultset("Stock::StockRelationship")->find_or_create({ subject_id => $progeny_plot->stock_id, object_id => $progeny_stock->stock_id, type_id => $plot_of_rel_type_id });

        # Link progeny plot to experiment of type 'field_layout' (required for materialized_phenoview and other search grids)
        my $progeny_experiment = $schema->resultset("NaturalDiversity::NdExperiment")->create({ nd_geolocation_id => $nd_geolocation_id, type_id => $field_layout_type_id });
        $progeny_experiment->create_related('nd_experiment_stocks', { stock_id => $progeny_plot->stock_id, type_id => $field_layout_type_id });
        $progeny_experiment->create_related('nd_experiment_projects', { project_id => $crossing_trial->project_id });

        # Progeny linked to cross
        $schema->resultset("Stock::StockRelationship")->find_or_create({ subject_id => $progeny_stock->stock_id, object_id => $cross_stock->stock_id, type_id => $offspring_of_rel_type_id });
        # Progeny also linked directly to parents (required for some progeny search types in CXGN::Cross)
        $schema->resultset("Stock::StockRelationship")->find_or_create({ subject_id => $parents{$c_info->{female}}, object_id => $progeny_stock->stock_id, type_id => $female_parent_rel_type_id, value => $c_info->{type} });
        $schema->resultset("Stock::StockRelationship")->find_or_create({ subject_id => $parents{$c_info->{male}}, object_id => $progeny_stock->stock_id, type_id => $male_parent_rel_type_id }) if $c_info->{male};
    }
}

# Refresh materialized views so they pick up the new stocks/experiments
$schema->storage->dbh->do("SELECT refresh_materialized_phenotype_jsonb_table()");
$schema->storage->dbh->do("REFRESH MATERIALIZED VIEW materialized_phenoview");

sub run_search_test {
    my %args = @_;
    my $page_url = $args{page_url};
    my $primary_input_id = $args{primary_input_id};
    my $primary_value = $args{primary_value};
    my $secondary_select_id = $args{secondary_select_id};
    my $secondary_value = $args{secondary_value};
    my $submit_btn_id = $args{submit_btn_id};
    my $results_table_id = $args{results_table_id};
    my $assertions = $args{assertions} || [];

    $d->get_ok($page_url);
    $d->wait_for_network_idle();

    # Input primary parent name
    $d->clear_ok($primary_input_id, "id", "Clear input $primary_input_id");
    $d->send_keys_ok($primary_input_id, "id", $primary_value, "Input primary parent name ($primary_input_id)");

    # Select secondary parent if specified
    if ($secondary_select_id && $secondary_value) {
        wait_until {
            # Click outside of the input to dismiss autocomplete dropdown
            $d->click("pagetitle", "id");
            my $val = $d->find_element($secondary_select_id, "id")->get_attribute('innerHTML');
            return $val =~ /\Q$secondary_value\E/;
        };
        $d->click_ok("//select[\@id='$secondary_select_id']/option[text()='$secondary_value']", 'xpath', "Select $secondary_value as secondary parent");
    }

    # Click search button
    $d->click_ok($submit_btn_id, "id", "click search button $submit_btn_id");
    $d->wait_for_network_idle();

    # Verify the results are loaded in the search results table
    $d->find_element_ok($results_table_id, "id", "find search results table");
    my $results_table = $d->find_element_ok($results_table_id, "id", "Get results table");
    my $results_text = $results_table->get_text();

    foreach my $assertion (@$assertions) {
        my $pattern = $assertion->{pattern};
        my $expected = $assertion->{expected};
        my $desc = $assertion->{desc};
        if ($expected) {
            ok($results_text =~ /$pattern/, $desc);
        } else {
            ok($results_text !~ /$pattern/, $desc);
        }
    }

    # Refresh the page and verify that search results are correctly restored from the URL
    $d->get_ok($d->driver->get_current_url(), "Refresh page to verify search state persistence");
    $d->wait_for_network_idle();

    my $results_table_after = $d->find_element_ok($results_table_id, "id", "Get results table after refresh");
    my $results_text_after = $results_table_after->get_text();
    foreach my $assertion (@$assertions) {
        my $pattern = $assertion->{pattern};
        my $expected = $assertion->{expected};
        my $desc = $assertion->{desc} . " (after refresh)";
        if ($expected) {
            ok($results_text_after =~ /$pattern/, $desc);
        } else {
            ok($results_text_after !~ /$pattern/, $desc);
        }
    }
}

$d->while_logged_in_as('submitter', sub {
    # Test 1: Search Progenies using female parent (All Progenies of this Female Parent)
    run_search_test(
        page_url                => '/search/progenies_using_female',
        primary_input_id        => 'pedigree_female_parent',
        primary_value           => 'CrossesTestFemale1',
        submit_btn_id           => 'search_all_progenies_using_female',
        results_table_id        => 'pedigree_female_male_search_results',
        assertions              => [
            { pattern => qr/CrossesTestCross1_progeny/, expected => 1, desc => 'Verify CrossesTestCross1_progeny is present' },
            { pattern => qr/CrossesTestCross1_progeny_sibling/, expected => 1, desc => 'Verify CrossesTestCross1_progeny_sibling is present' },
            { pattern => qr/CrossesTestCross2_progeny/, expected => 1, desc => 'Verify CrossesTestCross2_progeny is present' },
            { pattern => qr/CrossesTestCross3_progeny/, expected => 1, desc => 'Verify CrossesTestCross3_progeny is present' },
            { pattern => qr/CrossesTestCross4_progeny/, expected => 1, desc => 'Verify CrossesTestCross4_progeny is present' },
            { pattern => qr/CrossesTestCross5_progeny/, expected => 1, desc => 'Verify CrossesTestCross5_progeny is present' },
            { pattern => qr/CrossesTestCross6_progeny/, expected => 1, desc => 'Verify CrossesTestCross6_progeny is present' },
        ]
    );

    # Test 2: Search Progenies using both Female and Male parents
    run_search_test(
        page_url                => '/search/progenies_using_female',
        primary_input_id        => 'pedigree_female_parent',
        primary_value           => 'CrossesTestFemale1',
        secondary_select_id     => 'pedigree_male_parent',
        secondary_value         => 'CrossesTestMale1',
        submit_btn_id           => 'search_pedigree_female_male',
        results_table_id        => 'pedigree_female_male_search_results',
        assertions              => [
            { pattern => qr/CrossesTestCross1_progeny/, expected => 1, desc => 'CrossesTestCross1_progeny is present for specified parents' },
            { pattern => qr/CrossesTestCross1_progeny_sibling/, expected => 1, desc => 'CrossesTestCross1_progeny_sibling is present for specified parents' },
            { pattern => qr/CrossesTestCross2_progeny/, expected => 0, desc => 'CrossesTestCross2_progeny is NOT present for specified parents' },
        ]
    );

    # Test 3: Search Progenies using male parent (All Progenies of this Male Parent)
    run_search_test(
        page_url                => '/search/progenies_using_male',
        primary_input_id        => 'male_parent',
        primary_value           => 'CrossesTestMale1',
        submit_btn_id           => 'search_all_progenies_using_male',
        results_table_id        => 'pedigree_male_female_search_results',
        assertions              => [
            { pattern => qr/CrossesTestCross1_progeny/, expected => 1, desc => 'Verify CrossesTestCross1_progeny is present in search results' },
            { pattern => qr/CrossesTestCross1_progeny_sibling/, expected => 1, desc => 'Verify CrossesTestCross1_progeny_sibling is present in search results' },
            { pattern => qr/CrossesTestCross2_progeny/, expected => 0, desc => 'Verify CrossesTestCross2_progeny is NOT present in search results' },
        ]
    );

    # Test 4: Search Progenies using both Male and Female parents
    run_search_test(
        page_url                => '/search/progenies_using_male',
        primary_input_id        => 'male_parent',
        primary_value           => 'CrossesTestMale3',
        secondary_select_id     => 'female_parent',
        secondary_value         => 'CrossesTestFemale1',
        submit_btn_id           => 'search_pedigree_male_female',
        results_table_id        => 'pedigree_male_female_search_results',
        assertions              => [
            { pattern => qr/CrossesTestCross3_progeny/, expected => 1, desc => 'CrossesTestCross3_progeny is present for specified parents' },
            { pattern => qr/CrossesTestCross1_progeny/, expected => 0, desc => 'CrossesTestCross1_progeny is NOT present for specified parents' },
        ]
    );

    # Test 5: Search Crosses using female parent (All Crosses)
    run_search_test(
        page_url                => '/search/crosses_using_female',
        primary_input_id        => 'cross_female_parent',
        primary_value           => 'CrossesTestFemale1',
        submit_btn_id           => 'search_all_crosses_using_female',
        results_table_id        => 'cross_female_male_search_results',
        assertions              => [
            { pattern => qr/CrossesTestCross1/, expected => 1, desc => 'Verify CrossesTestCross1 is present in crosses search results' },
            { pattern => qr/CrossesTestCross2/, expected => 1, desc => 'Verify CrossesTestCross2 is present in crosses search results' },
            { pattern => qr/CrossesTestCross3/, expected => 1, desc => 'Verify CrossesTestCross3 is present in crosses search results' },
            { pattern => qr/CrossesTestCross4/, expected => 1, desc => 'Verify CrossesTestCross4 is present in crosses search results' },
            { pattern => qr/CrossesTestCross5/, expected => 1, desc => 'Verify CrossesTestCross5 is present in crosses search results' },
            { pattern => qr/CrossesTestCross6/, expected => 1, desc => 'Verify CrossesTestCross6 is present in crosses search results' },
        ]
    );

    # Test 6: Search Crosses using female and male parent
    run_search_test(
        page_url                => '/search/crosses_using_female',
        primary_input_id        => 'cross_female_parent',
        primary_value           => 'CrossesTestFemale1',
        secondary_select_id     => 'cross_male_parent',
        secondary_value         => 'CrossesTestMale1',
        submit_btn_id           => 'search_crosses_female_male',
        results_table_id        => 'cross_female_male_search_results',
        assertions              => [
            { pattern => qr/CrossesTestCross1/, expected => 1, desc => 'CrossesTestCross1 is present' },
            { pattern => qr/CrossesTestCross2/, expected => 0, desc => 'CrossesTestCross2 is NOT present' },
        ]
    );

    # Test 7: Search Crosses using male parent (All Crosses)
    run_search_test(
        page_url                => '/search/crosses_using_male',
        primary_input_id        => 'cross_male',
        primary_value           => 'CrossesTestMale1',
        submit_btn_id           => 'search_all_crosses_using_male',
        results_table_id        => 'cross_male_female_search_results',
        assertions              => [
            { pattern => qr/CrossesTestCross1/, expected => 1, desc => 'Verify CrossesTestCross1 is present in crosses search results' },
            { pattern => qr/CrossesTestCross2/, expected => 0, desc => 'Verify CrossesTestCross2 is NOT present' },
        ]
    );

    # Test 8: Search Crosses using both Male and Female parents
    run_search_test(
        page_url                => '/search/crosses_using_male',
        primary_input_id        => 'cross_male',
        primary_value           => 'CrossesTestMale3',
        secondary_select_id     => 'cross_female',
        secondary_value         => 'CrossesTestFemale1',
        submit_btn_id           => 'search_crosses_male_female',
        results_table_id        => 'cross_male_female_search_results',
        assertions              => [
            { pattern => qr/CrossesTestCross3/, expected => 1, desc => 'CrossesTestCross3 is present' },
            { pattern => qr/CrossesTestCross1/, expected => 0, desc => 'CrossesTestCross1 is NOT present' },
        ]
    );
});

$d->driver->quit();
$f->clean_up_db();
done_testing();
