use strict;
use warnings;
use utf8;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON qw(decode_json);
use URI;
use CXGN::Trial;
use CXGN::Trial::TrialCreate;
use SGN::Model::Cvterm;

my $f = SGN::Test::Fixture->new;
END { $f->clean_up_db() if $f; }
my $schema = $f->bcs_schema;
my $trial_name = "trait_unicode_$$";
my $creator = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema, dbh => $f->dbh, owner_id => 41,
    operator => 'janedoe', program => 'test', trial_location => 'test_location',
    trial_name => $trial_name, trial_year => 2030, design_type => 'CRD',
    trial_description => 'Unicode trait regression',
    design => { 1 => {
        plot_name => "${trial_name}_plot", plot_number => 1,
        stock_name => 'test_accession1',
        block_number => 1, rep_number => 1, row_number => 1, col_number => 1,
    } },
});
my $trial_id = $creator->save_trial->{trial_id};
ok($trial_id, 'created an isolated trial') or BAIL_OUT('trial setup failed');
my $trial = CXGN::Trial->new({ bcs_schema => $schema, trial_id => $trial_id });

my $template = $schema->resultset('Cv::Cvterm')->find(70773);
my @terms;
for my $suffix (qw(variable component)) {
    my $xref = $schema->resultset('General::Dbxref')->create({
        db_id => $template->dbxref->db_id, accession => "${trial_name}_$suffix",
    });
    push @terms, $schema->resultset('Cv::Cvterm')->create({
        cv_id => $template->cv_id, dbxref_id => $xref->dbxref_id,
        name => "${trial_name}_$suffix", definition => 'ASCII definition',
    });
}
my ($variable, $component) = @terms;
my $trait_id = $variable->cvterm_id;
my $contains = SGN::Model::Cvterm->get_cvterm_row($schema, 'contains', 'relationship');
my $experiment_type = SGN::Model::Cvterm->get_cvterm_row(
    $schema, 'phenotyping_experiment', 'experiment_type')->cvterm_id;
my $location = $schema->resultset('NaturalDiversity::NdGeolocation')
    ->find({ description => 'test_location' });
my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create({
    type_id => $experiment_type, nd_geolocation_id => $location->nd_geolocation_id,
});
my $phenotype = $schema->resultset('Phenotype::Phenotype')->create({
    uniquename => "${trial_name}_observation", cvalue_id => $trait_id, value => '12',
});
my $plot = $schema->resultset('Stock::Stock')->find({ uniquename => "${trial_name}_plot" });
$schema->resultset('NaturalDiversity::NdExperimentStock')->create({
    nd_experiment_id => $experiment->nd_experiment_id,
    stock_id => $plot->stock_id, type_id => $experiment_type,
});
$schema->resultset('NaturalDiversity::NdExperimentProject')->create({
    nd_experiment_id => $experiment->nd_experiment_id, project_id => $trial_id,
});
$schema->resultset('NaturalDiversity::NdExperimentPhenotype')->create({
    nd_experiment_id => $experiment->nd_experiment_id, phenotype_id => $phenotype->phenotype_id,
});

is_deeply($trial->get_traits_assayed->[0][2], [], 'traits without components still return an empty array');
$schema->resultset('Cv::CvtermRelationship')->create({
    subject_id => $component->cvterm_id, object_id => $trait_id, type_id => $contains->cvterm_id,
});

my $mech = Test::WWW::Mechanize->new;
$mech->post_ok('http://localhost:3010/brapi/v1/token', {
    username => 'janedoe', password => 'secretpw', grant_type => 'password',
}, 'log in with the fixture user');

for my $case (
    ['ASCII', 'height', 'Plant height'],
    ['accented name', 'altura média', 'Plant height'],
    ['accented definition', 'height', 'Média em °C'],
    ['non-Latin name', 'Висота рослини', 'Plant height'],
    ['non-Latin definition', 'height', '植物の高さ'],
    ['mixed Unicode', 'café – ύψος 🌱', "Définition: \"hauteur\"\n植物の高さ"],
    ['literal UTF-8-looking characters', 'Ã©', 'Ã¼'],
    ['undefined definition', 'height', undef],
) {
    my ($label, $name, $definition) = @$case;
    subtest $label => sub {
        $variable->update({ name => "${trial_name}_$name" });
        $component->update({ name => $name, definition => $definition });

        for my $stock_type (undef, 'plot') {
            my $traits = eval { $trial->get_traits_assayed($stock_type) };
            is($@, '', 'assayed traits decode successfully') or next;
            is(scalar(@$traits), 1, 'one assayed trait is returned');
            is($traits->[0][1], $variable->name . '|' . $variable->dbxref->db->name
                . ':' . $variable->dbxref->accession, 'variable name is preserved');
            is($traits->[0][3], 1, 'phenotype count is preserved');
            is($traits->[0][2][0]{name}, $name, 'component name is preserved');
            is($traits->[0][2][0]{definition}, $definition, 'component definition is preserved');
        }

        my $assayed = request_json("/ajax/breeders/trial/$trial_id/traits_assayed", {
            stock_type => 'plot',
        });
        my $components = $assayed->{traits_assayed}[0][0][2];
        is($components->[0]{name}, $name, 'trait list endpoint preserves the component name');
        is($components->[0]{definition}, $definition, 'trait list endpoint preserves the definition');

        for my $format (qw(html_select component_table_select)) {
            my $select = request_json('/ajax/html/select/traits', {
                trial_ids => $trial_id, data_level => 'plot', select_format => $format,
            });
            like($select->{select} // '', qr/\Q$name\E/, "$format preserves the trait name");
        }

        my $summary = request_json("/ajax/breeders/trial/$trial_id/phenotypes", { display => 'plots' });
        like($summary->{data}[0][0] // '', qr/\Q$name\E/, 'summary table preserves the variable name');
    };
}

sub request_json {
    my ($path, $params) = @_;
    my $url = URI->new("http://localhost:3010$path");
    $url->query_form(%$params);
    $mech->get_ok($url, "$path responds successfully");
    my $response = eval { decode_json($mech->response->content) };
    is($@, '', "$path returns valid UTF-8 JSON");
    return $response || {};
}

done_testing();
