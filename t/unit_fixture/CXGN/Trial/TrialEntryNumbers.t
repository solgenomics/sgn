use strict;

use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;

use SGN::Model::Cvterm;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::ParseUpload;


my $fix = SGN::Test::Fixture->new();

for my $extension ("xls", "xlsx") {

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
            chado_schema      => $chado_schema,
            dbh               => $dbh,
            owner_id          => 41,
            design            => $design,
            program           => "test",
            trial_year        => "2015",
            trial_description => "test description",
            trial_location    => "test_location",
            trial_name        => "subplot_test_trial",
            trial_type        => $ayt_cvterm_id,
            design_type       => "RCBD",
            operator          => "janedoe"
        }),
        "create trial object"
    );

    my $save = $trial_create->save_trial();
    ok(my $trial_id = $save->{'trial_id'}, "save trial");


    #
    # ADD TRIAL ENTRY NUMBERS
    #

    my $trial = CXGN::Trial->new({
        bcs_schema      => $chado_schema,
        metadata_schema => $metadata_schema,
        phenome_schema  => $phenome_schema,
        trial_id        => $trial_id
    });

    my $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/trial/trial_entry_numbers_upload.$extension", chado_schema => $chado_schema });
    $p->load_plugin("TrialEntryNumbers");
    my $parsed_data = $p->parse();
    my $errors = $p->get_parse_errors();
    ok(!$errors, "no parse errors");

    foreach my $id (keys %$parsed_data) {
        $trial->set_entry_numbers($parsed_data->{$id});
    }

    my $entry_number_map = $trial->get_entry_numbers();
    ok(!!$entry_number_map, "trial entry numbers exist");


    #
    # Remove Trial
    #
    $trial->delete_metadata();
    $trial->delete_field_layout();
    $trial->delete_project_entry();

    $fix->clean_up_db();
}
done_testing();