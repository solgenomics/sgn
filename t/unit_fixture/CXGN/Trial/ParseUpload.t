
use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;
use CXGN::Trial::ParseUpload;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();

my $p = CXGN::Trial::ParseUpload->new( { filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template", chado_schema=> $f->bcs_schema() });
$p->load_plugin("ParseIGDFile");

my $results = $p->parse();
my $errors = $p->get_parse_errors();

ok(scalar(@{$errors->{'error_messages'}}) == 0, "no parse errors");

is_deeply( $results, { trial_name => "CASSAVA_GS_74", blank_well => "F05", user_id=>'I.Rabbi@cgiar.org', project_name => 'NEXTGENCASSAVA' }, "parse results test");

#print STDERR join ",", @{$errors->{'error_messages'}};

$p = CXGN::Trial::ParseUpload->new( { filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_missing_blank", chado_schema=> $f->bcs_schema() });
$p->load_plugin("ParseIGDFile");

$results = $p->parse();
$errors = $p->get_parse_errors();

ok($errors->{'error_messages'}->[0] eq "No blank well found in spreadsheet", "detect missing blank entry");

$p = CXGN::Trial::ParseUpload->new( { filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_messed_up_trial_name", chado_schema=> $f->bcs_schema() });
$p->load_plugin("ParseIGDFile");

$results = $p->parse();
$errors = $p->get_parse_errors();

ok($errors->{'error_messages'}->[0] eq "All trial names in the trial column must be identical", "detect messed up trial name");

$p = CXGN::Trial::ParseUpload->new( { filename => "t/data/trial/trial_layout_bad_accessions.xls", chado_schema=> $f->bcs_schema() });
$p->load_plugin("TrialExcelFormat");

$results = $p->parse();
$errors = $p->get_parse_errors();
#print STDERR Dumper $errors;
ok($errors->{'error_messages'}->[0], 'Cell J1: seedlot_name is missing from the header. (Header is required, but values are optional)');
ok($errors->{'error_messages'}->[1], 'Cell K1: num_seed_per_plot is missing from the header. (Header is required, but values are optional)');
ok(scalar(@{$errors->{'error_messages'}}) == 4, 'check that accessions not in db and file missing seedlot_name and num_seed_per_plot and weight_gram_seed_per_plot headers');
ok(scalar(@{$errors->{'missing_accessions'}}) == 8, 'check that accessions not in db');

$p = CXGN::Trial::ParseUpload->new( { filename => "t/data/genotype_trial_upload/CASSAVA_GS_74Template_messed_up_trial_name", chado_schema=> $f->bcs_schema() });
$p->load_plugin("TrialExcelFormat");

$results = $p->parse();
$errors = $p->get_parse_errors();
ok($errors->{'error_messages'}->[0] eq "No Excel data found in file", 'check that accessions not in db');


done_testing();
