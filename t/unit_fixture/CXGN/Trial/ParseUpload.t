
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::Trial::ParseUpload;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();

for my $extension ("xls", "xlsx", "csv") {

    my $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template.csv", chado_schema => $f->bcs_schema() });
    $p->load_plugin("ParseIGDFile");

    my $results = $p->parse();
    my $errors = $p->get_parse_errors();

    ok(scalar(@{$errors->{'error_messages'}}) == 0, "no parse errors");

    is_deeply($results, { trial_name => "CASSAVA_GS_74", blank_well => "F05", user_id => 'I.Rabbi@cgiar.org', project_name => 'NEXTGENCASSAVA' }, "parse results test");

    #print STDERR join ",", @{$errors->{'error_messages'}};

    $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_missing_blank.csv", chado_schema => $f->bcs_schema() });
    $p->load_plugin("ParseIGDFile");

    $results = $p->parse();
    $errors = $p->get_parse_errors();

    ok($errors->{'error_messages'}->[0] eq "No blank well found in spreadsheet", "detect missing blank entry");

    $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_messed_up_trial_name.csv", chado_schema => $f->bcs_schema() });
    $p->load_plugin("ParseIGDFile");

    $results = $p->parse();
    $errors = $p->get_parse_errors();

    ok($errors->{'error_messages'}->[0] eq "All trial names in the trial column must be identical", "detect messed up trial name");

    $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/trial/trial_layout_bad_accessions.$extension", chado_schema => $f->bcs_schema() });
    $p->load_plugin("TrialGeneric");

    $results = $p->parse();
    $errors = $p->get_parse_errors();
    #print STDERR Dumper $errors;
    ok($errors->{'error_messages'}->[0] =~ /The following entry names are not in the database as uniquenames or synonyms/, 'check that accessions not in db');
    ok(scalar(@{$errors->{'error_messages'}}) == 1, 'check that accessions not in db');
    ok(scalar(@{$errors->{'missing_stocks'}}) == 8, 'check that accessions not in db');

    $p = CXGN::Trial::ParseUpload->new({ filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_messed_up_trial_name.csv", chado_schema => $f->bcs_schema() });
    $p->load_plugin("TrialGeneric");

    $results = $p->parse();
    $errors = $p->get_parse_errors();
    my $expected = {
        'error_messages' => [
            'Required column stock_name is missing',
            'Required column plot_number is missing',
            'Required column block_number is missing'
        ]
    };
    is_deeply($errors, $expected, 'check file format errors');

    $f->clean_up_db();
}

done_testing();
