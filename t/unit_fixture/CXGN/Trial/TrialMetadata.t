
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::Trial::ParseUpload;
use CXGN::Project;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema();

for my $extension ("xls", "xlsx", "csv") {

    # Parse and Validate The File
    my $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/trial/trial_metadata.$extension", chado_schema => $schema });
    $p->load_plugin("TrialMetadataGeneric");
    my $results = $p->parse();
    my $errors = $p->get_parse_errors();

    # Expected parsed data
    my $expected = {
        'trial_data' => {
            '165' => {
                'trial_name' => 'CASS_6Genotypes_Sampling_2015',
                'harvest_date' => '2017-07-19',
                'description' => undef,
                'year' => undef,
                'name' => 'updated_trial',
                'location' => undef,
                'type' => undef,
                '_row' => 3,
                'breeding_program' => undef,
                'planting_date' => '2017-06-02',
                'design_type' => undef,
                'plot_width' => undef,
                'plot_length' => undef,
                'field_size' => undef
            },
            '137' => {
                'trial_name' => 'test_trial',
                'description' => 'Updated Description',
                'harvest_date' => 'remove',
                'location' => 24,
                'name' => undef,
                '_row' => 2,
                'type' => 76514,
                'year' => '2017',
                'breeding_program' => undef,
                'design_type' => 'RCBD',
                'planting_date' => '2017-06-01',
                'plot_width' => '1.5',
                'plot_length' => '1',
                'field_size' => '10'
            }
        },
        'breeding_programs' => [
            'test'
        ]
    };

    # Check file parsing
    is($errors, undef, 'parse error');
    is_deeply($results, $expected, 'parse results');

    # Save the trial metadata
    my $trial_data = $results->{'trial_data'};
    foreach my $trial_id (keys %$trial_data) {
        my $details = $trial_data->{$trial_id};
        my $trial = CXGN::Project->new({ bcs_schema => $schema, trial_id => $trial_id });
        my $error = $trial->update_metadata($details);
        is($error, '', 'update metadata error');
    }

    # Check Trial 1
    my $t1 = CXGN::Project->new({ bcs_schema => $schema, trial_id => 165 });
    is($t1->get_name(), "updated_trial", "trial 1 name");
    is($t1->get_year(), "2017", "trial 1 year");
    is($t1->get_description(), "Copy of trial with postcomposed phenotypes from cassbase.", "trial 1 description");
    is_deeply($t1->get_location(), ["23", "test_location"], "trial 1 location");
    is_deeply($t1->get_project_type, [76515, "Preliminary Yield Trial", undef], "trial 1 project type");
    is($t1->get_breeding_program(), "test", "trial 1 breeding program");
    is($t1->get_planting_date(), "2017-June-02", "trial 1 planting date");
    is($t1->get_harvest_date(), "2017-July-19", "trial 1 harvest date");
    is($t1->get_plot_width(), undef, "trial 1 plot width");
    is($t1->get_plot_length(), undef, "trial 1 plot length");
    is($t1->get_field_size(), undef, "trial 1 field size");
    is($t1->get_design_type(), "RCBD", "trial 1 design type");

    # Check Trial 2
    my $t2 = CXGN::Project->new({ bcs_schema => $schema, trial_id => 137 });
    is($t2->get_name(), "test_trial", "trial 2 name");
    is($t2->get_year(), "2017", "trial 2 year");
    is($t2->get_description(), "Updated Description", "trial 2 description");
    is_deeply($t2->get_location(), ["24", "Cornell Biotech"], "trial 2 location");
    is_deeply($t2->get_project_type, [76514, "Advanced Yield Trial", undef], "trial 2 project type");
    is($t2->get_breeding_program(), "test", "trial 2 breeding program");
    is($t2->get_planting_date(), "2017-June-01", "trial 2 planting date");
    is($t2->get_harvest_date(), undef, "trial 2 harvest date");
    is($t2->get_plot_width(), "1.5", "trial 2 plot width");
    is($t2->get_plot_length(), "1", "trial 2 plot length");
    is($t2->get_field_size(), "10", "trial 2 field size");
    is($t2->get_design_type(), "RCBD", "trial 2 design type");


    # Reset metadata
    my %original_t1_metadata = (
        name => "CASS_6Genotypes_Sampling_2015",
        planting_date => "remove",
        harvest_date => "remove"
    );
    my %original_t2_metadata = (
        location => 23,
        year => "2014",
        planting_date => "2017-07-04",
        harvest_date => "2017-07-21",
        design_type => "CRD",
        description => "test trial",
        type => 76515,
        plot_width => undef,
        plot_length => undef,
        field_size => undef
    );

    my $e1 = $t1->update_metadata(\%original_t1_metadata);
    my $e2 = $t2->update_metadata(\%original_t2_metadata);
    is($e1, "", "trial 1 restore metadata");
    is($e2, "", "trial 2 restore metadata");

    $f->clean_up_db();

}

done_testing();
