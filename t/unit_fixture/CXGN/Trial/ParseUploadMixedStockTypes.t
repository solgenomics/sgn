use strict;
use warnings;
use lib 't/lib';

use Data::Dumper;
use File::Temp qw(tempfile);
use Text::CSV;
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::ParseUpload;

my $fixture = SGN::Test::Fixture->new();
my $schema = $fixture->bcs_schema();

my $cross_type_id = SGN::Model::Cvterm
    ->get_cvterm_row($schema, 'cross', 'stock_type')
    ->cvterm_id();
my $organism = $schema->resultset('Organism::Organism')->find_or_create({
    genus => 'Test_genus',
    species => 'Test_genus test_species',
});
$schema->resultset('Stock::Stock')->create({
    organism_id => $organism->organism_id(),
    name => 'cross_for_mixed_trial_upload',
    uniquename => 'cross_for_mixed_trial_upload',
    type_id => $cross_type_id,
});

my $parser = CXGN::Trial::ParseUpload->new(
    chado_schema => $schema,
    filename => 't/data/trial/multiple_trial_layout_mixed_accession_cross.csv',
);
$parser->load_plugin('MultipleTrialDesignGeneric');
my $parsed = $parser->parse();

diag(Dumper($parser->get_parse_errors())) if $parser->has_parse_errors();
ok($parsed, 'parse a multi-trial file containing accession and cross trials');
ok(!$parser->has_parse_errors(), 'validate stocks using each trial stock type');

# Existing spreadsheets can omit trial_stock_type or call a mixed trial an
# accession trial. Infer the type from its actual stocks and pass it to storage.
foreach my $declared_type ('accession', '', 'omitted') {
    my ($fh, $filename) = tempfile(SUFFIX => '.csv', UNLINK => 1);
    my $csv = Text::CSV->new({ binary => 1, eol => "\n" });
    my @columns = qw(trial_name breeding_program location year design_type description accession_name plot_number block_number trial_type seedlot_name);
    push @columns, 'trial_stock_type' unless $declared_type eq 'omitted';
    $csv->print($fh, \@columns);
    foreach my $entry (
        ['mixed_inferred_trial', 'cross_for_mixed_trial_upload', 1],
        ['mixed_inferred_trial', 'UG120001', 2],
        ['accession_only_trial', 'UG120001', 1],
    ) {
        my @row = ($entry->[0], 'test', 'test_location', 2026, 'CRD', 'Mixed stocks', $entry->[1], $entry->[2], 1, '', '');
        push @row, $declared_type unless $declared_type eq 'omitted';
        $csv->print($fh, \@row);
    }
    close $fh;
    my $mixed_parser = CXGN::Trial::ParseUpload->new(chado_schema => $schema, filename => $filename);
    $mixed_parser->load_plugin('MultipleTrialDesignGeneric');
    my $mixed = $mixed_parser->parse();
    ok($mixed, "accept mixed stocks with trial_stock_type '$declared_type'");
    diag(Dumper($mixed_parser->get_parse_errors())) unless $mixed;
    is($mixed->{'mixed_inferred_trial'}->{'trial_stock_type'}, 'cross', 'pass inferred cross type to trial storage');
    is($mixed->{'accession_only_trial'}->{'trial_stock_type'}, 'accession', 'keep accession-only trial type');
}

my $single_parser = CXGN::Trial::ParseUpload->new(
    chado_schema => $schema,
    filename => 't/data/trial/trial_layout_mixed_accession_cross.csv',
    trial_name => 'mixed_single_trial',
    trial_stock_type => 'cross',
);
$single_parser->load_plugin('TrialGeneric');
my $single_parsed = $single_parser->parse();

diag(Dumper($single_parser->get_parse_errors())) if $single_parser->has_parse_errors();
ok($single_parsed, 'parse one cross trial containing accession and cross stocks');
ok(!$single_parser->has_parse_errors(), 'validate mixed accession and cross stocks in one cross trial');

$fixture->clean_up_db();
done_testing();
