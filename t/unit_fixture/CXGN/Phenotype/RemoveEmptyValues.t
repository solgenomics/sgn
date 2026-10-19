
=head1 NAME

t/unit_fixture/CXGN/Phenotype/RemoveEmptyValues.t - overwrite and remove values with NA and '.'

=head1 DESCRIPTION

Stores a value for a plot and trait, then uploads an empty marker ('NA' or '.')
for the same plot and trait with overwrite_values set.

With remove_values set, the old value must be deleted and counted as removed.
Without remove_values, the empty marker must be skipped and the old value kept.

=cut

use strict;
use warnings;

use Test::More;
use lib 't/lib';

use SGN::Test::Fixture;
use CXGN::Phenotypes::StorePhenotypes;

my $f = SGN::Test::Fixture->new();

my $plot  = 'test_trial21';
my $trait = 'dry matter content|CO_334:0000092';

sub stored_values {
    my $q = "SELECT phenotype.value
               FROM phenotype
               JOIN cvterm ON (phenotype.cvalue_id = cvterm.cvterm_id)
               JOIN dbxref USING (dbxref_id)
               JOIN db USING (db_id)
               JOIN nd_experiment_phenotype USING (phenotype_id)
               JOIN nd_experiment_stock USING (nd_experiment_id)
               JOIN stock USING (stock_id)
              WHERE stock.uniquename = ?
                AND db.name = 'CO_334' AND dbxref.accession = '0000092'
              ORDER BY phenotype.value";
    my $h = $f->dbh()->prepare($q);
    $h->execute($plot);
    my @values;
    while (my ($v) = $h->fetchrow_array()) { push @values, $v; }
    return \@values;
}

sub upload {
    my ($value, $overwrite, $remove) = @_;

    my $store = CXGN::Phenotypes::StorePhenotypes->new(
        basepath => $f->config->{basepath},
        dbhost => $f->config->{dbhost},
        dbname => $f->config->{dbname},
        dbuser => $f->config->{dbuser},
        dbpass => $f->config->{dbpass},
        temp_file_nd_experiment_id => $f->config->{cluster_shared_tempdir}."/test_temp_nd_experiment_id_remove_empty",
        bcs_schema => $f->bcs_schema,
        metadata_schema => $f->metadata_schema,
        phenome_schema => $f->phenome_schema,
        user_id => 41, #janedoe in fixture
        stock_list => [$plot],
        trait_list => [$trait],
        values_hash => { $plot => { $trait => [[$value, '']] } },
        has_timestamps => 0,
        overwrite_values => $overwrite,
        remove_values => $remove,
        metadata_hash => {
            archived_file => 'none',
            archived_file_type => 'new stock phenotypes',
            operator => 'janedoe',
            date => '2016-02-16_01:10:56',
        },
        composable_validation_check_name => $f->config->{composable_validation_check_name},
    );

    my ($verified_warning, $verified_error) = $store->verify();
    ok(!$verified_error, "verify '$value' (overwrite=$overwrite, remove=$remove)") or diag $verified_error;
    my ($error, $success) = $store->store();
    ok(!$error, "store '$value' (overwrite=$overwrite, remove=$remove)") or diag $error;
    return $success;
}

is_deeply(stored_values(), [], 'no starting value for the plot and trait');

upload('42', 1, 0);
is_deeply(stored_values(), ['42'], 'a value is stored');

foreach my $empty ('NA', '.') {
    my $msg = upload($empty, 1, 0);
    is_deeply(stored_values(), ['42'], "'$empty' without remove_values keeps the old value");
    like($msg, qr/1 previously stored values skipped/, "'$empty' without remove_values is skipped");
    like($msg, qr/0 previously stored values removed/, "'$empty' without remove_values removes nothing");

    $msg = upload($empty, 1, 1);
    is_deeply(stored_values(), [], "'$empty' with remove_values removes the old value");
    like($msg, qr/1 previously stored values removed/, "'$empty' with remove_values is counted as removed");

    upload('42', 1, 0);
    is_deeply(stored_values(), ['42'], 'the value is stored again');
}

# clean up, other test files share the fixture database
upload('', 1, 1);
is_deeply(stored_values(), [], 'cleaned up');

done_testing();
