
use strict;

use Data::Dumper;
use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use File::Temp qw | tempfile |;
use CXGN::Stock::Accession;

my $f = SGN::Test::Fixture->new();

my $file = "t/data/stock/test_load_stock_script.csv";

my ($fh, $temp_file) = tempfile( "load_stocks_stderr_XXXXX", DIR => "/tmp" );
my $dbhost = $f->config->{dbhost};
my $dbname = $f->config->{dbname};
my $dbpass = $f->config->{dbpass};

my $cmd_line = "perl bin/load_stocks.pl -H $dbhost -u janedoe -D $dbname -P $dbpass -i $file 2> $temp_file";

print STDERR "$cmd_line\n";

my @out = `$cmd_line\n`;

open(my $F, "<", $temp_file) || die "Can't open file $temp_file\n";
my @lines = <$F>;
close($F);

my $q1 = "SELECT stock_id FROM stock where uniquename = 'script_added_1'";
my $h1 = $f->dbh()->prepare($q1);
$h1->execute();
my ($stock_id) = $h1->fetchrow_array();

ok($stock_id, "stock id verification test");

my $stock = CXGN::Stock::Accession->new( schema => $f->bcs_schema, phenome_schema => $f->phenome_schema, metadata_schema => $f->metadata_schema, stock_id => $stock_id );

is_deeply($stock->synonyms, [ 'besty1', 'super1' ], "stock synonyms test");

print STDERR "POPULATIONS: ".Dumper($stock->populations());
is_deeply($stock->populations()->[0]->[1], 'xyz', "populations test");

is($stock->description(), "the very best", "stock description test");

$f->clean_up_db();

done_testing();

print STDERR "Done.\n";
