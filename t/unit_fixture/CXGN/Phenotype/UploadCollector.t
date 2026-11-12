
=head1 NAME

t/unit_fixture/CXGN/Phenotype/UploadCollector.t - the collector of each value in one upload

=head1 DESCRIPTION

Uploads one value per plot for six plots; five rows name a collector (alice or
bob) and one row has none, as in a Field Book file with an empty C<person>.

The value without a collector must get the user who uploads (the C<operator> of
the upload metadata), whatever the order of the plots. The phenotyping
experiments of the upload must keep that user as their operator, too.

=cut

use strict;
use warnings;

use Test::More;
use lib 't/lib';

use SGN::Test::Fixture;
use CXGN::Phenotypes::StorePhenotypes;

my $f = SGN::Test::Fixture->new();
my $dbh = $f->dbh();

my $trait = 'fresh shoot weight measurement in kg|CO_334:0000016';
my %collector_of = (
    test_trial21 => 'alice',
    test_trial22 => 'bob',
    test_trial23 => '',
    test_trial24 => 'alice',
    test_trial25 => 'bob',
    test_trial26 => 'alice',
);
my @plots = sort keys %collector_of;
my $placeholders = join ',', ('?') x @plots;

# value and collector of the trait for each plot
sub stored {
    my $h = $dbh->prepare("SELECT stock.uniquename, phenotype.value, phenotype.operator
          FROM phenotype
          JOIN cvterm ON (phenotype.cvalue_id = cvterm.cvterm_id)
          JOIN dbxref USING (dbxref_id)
          JOIN db USING (db_id)
          JOIN nd_experiment_phenotype USING (phenotype_id)
          JOIN nd_experiment_stock USING (nd_experiment_id)
          JOIN stock USING (stock_id)
         WHERE db.name = 'CO_334' AND dbxref.accession = '0000016'
           AND stock.uniquename IN ($placeholders)");
    $h->execute(@plots);
    my %stored;
    while (my ($plot, $value, $operator) = $h->fetchrow_array()) {
        push @{$stored{$plot}}, [ $value, $operator ];
    }
    return \%stored;
}

# operators of the phenotyping experiments of these plots made after $min_id
sub experiment_operators {
    my $min_id = shift;
    my $h = $dbh->prepare("SELECT DISTINCT nd_experimentprop.value
          FROM nd_experiment
          JOIN nd_experiment_stock USING (nd_experiment_id)
          JOIN stock USING (stock_id)
          JOIN nd_experimentprop USING (nd_experiment_id)
          JOIN cvterm ON (nd_experimentprop.type_id = cvterm.cvterm_id)
          JOIN cv USING (cv_id)
         WHERE nd_experiment.nd_experiment_id > ?
           AND cvterm.name = 'operator' AND cv.name = 'local'
           AND stock.uniquename IN ($placeholders)
         ORDER BY 1");
    $h->execute($min_id, @plots);
    return [ map { $_->[0] } @{$h->fetchall_arrayref()} ];
}

sub max_experiment_id {
    my ($id) = $dbh->selectrow_array("SELECT max(nd_experiment_id) FROM nd_experiment");
    return $id;
}

is_deeply(stored(), {}, 'no values of the trait on the plots before the test');

# the plots are stored in hash order, so the upload is repeated
foreach my $round (1..3) {
    my %values_hash;
    foreach my $plot (@plots) {
        my $value = 10 * $round + substr($plot, -1);
        $values_hash{$plot} = { $trait => [[ $value, '', $collector_of{$plot} ]] };
    }

    my $store = CXGN::Phenotypes::StorePhenotypes->new(
        basepath => $f->config->{basepath},
        dbhost => $f->config->{dbhost},
        dbname => $f->config->{dbname},
        dbuser => $f->config->{dbuser},
        dbpass => $f->config->{dbpass},
        temp_file_nd_experiment_id => $f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_upload_collector",
        bcs_schema => $f->bcs_schema,
        metadata_schema => $f->metadata_schema,
        phenome_schema => $f->phenome_schema,
        user_id => 41, #janedoe in fixture
        stock_list => \@plots,
        trait_list => [$trait],
        values_hash => \%values_hash,
        has_timestamps => 0,
        overwrite_values => 1,
        metadata_hash => {
            archived_file => 'none',
            archived_file_type => 'new stock phenotypes',
            operator => 'janedoe',
            date => '2026-11-12_10:00:00',
        },
        composable_validation_check_name => $f->config->{composable_validation_check_name},
    );

    my $min_id = max_experiment_id();
    my ($verified_warning, $verified_error) = $store->verify();
    ok(!$verified_error, "round $round: verify") or diag $verified_error;
    my ($error, $success) = $store->store();
    ok(!$error, "round $round: store") or diag $error;

    my $stored = stored();
    foreach my $plot (@plots) {
        my $value = 10 * $round + substr($plot, -1);
        my $collector = $collector_of{$plot} || 'janedoe';
        is_deeply($stored->{$plot}, [[ $value, $collector ]], "round $round: $plot has $value collected by $collector");
    }
    is_deeply(experiment_operators($min_id), ['janedoe'], "round $round: the experiments of the upload have janedoe as operator");
}

# other test files share the fixture database
$f->clean_up_db();
is_deeply(stored(), {}, 'cleaned up');

done_testing();
