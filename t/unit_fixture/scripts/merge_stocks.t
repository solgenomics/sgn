
use strict;

use Data::Dumper;
use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use File::Temp qw | tempfile |;

my $f = SGN::Test::Fixture->new();

my $file = "t/data/scripts/merge_stocks_test_file.txt";

print STDERR "adding merge candidate accession to db...\n";

my $q = "INSERT INTO stock (organism_id, name, uniquename, type_id) values ((SELECT organism_id FROM organism where species ilike 'Solanum lycopersicum'), 'merge_candidate', 'merge_candidate', (SELECT cvterm_id FROM cvterm where name ='accession'))";

my $h = $f->dbh()->prepare($q);

$h->execute();

print STDERR "Running merge script...\n";

my ($fh, $temp_file) = tempfile( "merge_test_stderr_XXXXX", DIR => "/tmp" );
my $dbhost = $f->config->{dbhost};
my $dbname = $f->config->{dbname};
my $dbpass = $f->config->{dbpass};

my $cmd_line = "perl bin/merge_stocks.pl -H $dbhost -D $dbname -x -P $dbpass $file 2> $temp_file";

print STDERR "$cmd_line\n";

my @out = `$cmd_line\n`;

open(my $F, "<", $temp_file) || die "Can't open file $temp_file\n";
my @lines = <$F>;
close($F);

ok( grep( /Relationships moved:/, @lines ), "relationships moved presence test");
ok( grep( /Stock props: 0/, @lines), "stock props 0 test");
ok( grep( /Added old name as synonym: 1/, @lines), "added old name as synonym");

my $q2 = "SELECT * FROM stock where uniquename = 'merge_candidate'";
my $h2 = $f->dbh()->prepare($q2);
$h2->execute();
my $results = $h2->fetchall_arrayref();

print STDERR "RESULTS: ".Dumper($results);
ok(! scalar(@$results), "check that merge_candidate disappeared by merge");

$f->clean_up_db();

done_testing();

print STDERR "Done.\n";
