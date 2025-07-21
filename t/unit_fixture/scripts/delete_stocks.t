
use strict;

use Data::Dumper;
use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use File::Temp qw | tempfile |;

my $f = SGN::Test::Fixture->new();

my $file = "t/data/scripts/stock_deletion_test_data.txt";

print STDERR "adding deletion candidate accession to db...\n";

my $q = "INSERT INTO stock (organism_id, name, uniquename, type_id) values ((SELECT organism_id FROM organism where species ilike 'Solanum lycopersicum'), 'merge_candidate', 'delete_candidate', (SELECT cvterm_id FROM cvterm where name ='accession'))";

my $h = $f->dbh()->prepare($q);

$h->execute();



my ($fh, $temp_file) = tempfile( "delete_test_stderr_XXXXX", DIR => "/tmp" );
my $dbhost = $f->config->{dbhost};
my $dbname = $f->config->{dbname};
my $dbpass = $f->config->{dbpass};


print STDERR "Running delete script with host $dbhost and db $dbname and pass $dbpass...\n";

my $cmd_line = "perl bin/delete_stocks.pl -H $dbhost -D $dbname -p $dbpass $file 2> $temp_file";

print STDERR "$cmd_line\n";

my @out = `$cmd_line\n`;

open(my $F, "<", $temp_file) || die "Can't open file $temp_file\n";
my @lines = <$F>;
close($F);

print "OUTPUT: \n".join("\n", @lines)."\n";

#ok( grep( /Relationships moved:/, @lines ), "relationships moved presence test");
#ok( grep( /Stock props: 0/, @lines), "stock props 0 test");
#ok( grep( /Added old name as synonym: 1/, @lines), "added old name as synonym");


