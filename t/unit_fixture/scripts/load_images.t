
use strict;

use Data::Dumper;
use Test::More;
use lib 't/lib';
use SGN::Test::Fixture;
use File::Temp qw | tempfile |;
use CXGN::Stock::Accession;

my $f = SGN::Test::Fixture->new();

my $file = "t/data/images/mapping_file.xlsx";

my ($fh, $temp_file) = tempfile( "load_stocks_stderr_XXXXX", DIR => "/tmp" );
my $dbhost = $f->config->{dbhost};
my $dbname = $f->config->{dbname};
my $dbpass = $f->config->{dbpass};

my $image_path = $f->config->{static_datasets_path} ."/". $f->config->{image_dir};
my $basepath = $f->config->{basepath};

print STDERR "BASEPATH = $basepath\n";
# load images using the mapping file approach
#


my $cmd_line = "perl bin/load_images.pl -H $dbhost -u janedoe  -D $dbname -P $dbpass -m $basepath/t/data/images/mapping_file.csv -y -i $basepath/t/data/images/by_stock_name/ -b $image_path  2> $temp_file";

print STDERR "$cmd_line\n";

my @out = `$cmd_line\n`;

open(my $F, "<", $temp_file) || die "Can't open file $temp_file\n";
my @lines = <$F>;
print STDERR join("\n", @lines);
close($F);

exit(0);
# load images using the named directories approach
#
my $cmd_line = "perl bin/load_images.pl -H $dbhost -u janedoe  -D $dbname -P $dbpass -m $basepath/t/data/images/mapping_file.xlsx -i t/data/images/by_stock_name/ -b $image_path 2> $temp_file";

print STDERR "$cmd_line\n";

my @out = `$cmd_line\n`;

$f->clean_up_db();

done_testing();

print STDERR "Done.\n";
