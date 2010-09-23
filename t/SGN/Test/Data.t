#!/usr/bin/env perl

use lib 't/lib';
use Test::More;

use_ok('SGN::Test::Data',
    qw/
    create_test_organism create_test_dbxref
    create_test_feature create_test_cvterm create_test_db
    /);

my $schema = SGN::Context->new->dbic_schema('Bio::Chado::Schema', 'sgn_test');

{
    my $db = create_test_db({
                    name => "SGNTESTDATA_$$",
                });

    isa_ok($db, 'Bio::Chado::Schema::General::Db');
    my $rs = $schema->resultset('General::Db')
        ->search({ name => "SGNTESTDATA_$$" });
    is($rs->count, 1, 'found exactly one db that was created');
}
{
    my $dbxref = create_test_dbxref({
                    accession => "SGNTESTDATA_$$",
                });

    isa_ok($dbxref, 'Bio::Chado::Schema::General::Dbxref');

    my $rs = $schema->resultset('General::Dbxref')
        ->search({ accession => "SGNTESTDATA_$$" });
    is($rs->count, 1, 'found exactly one dbxref that was created');
}

done_testing;
