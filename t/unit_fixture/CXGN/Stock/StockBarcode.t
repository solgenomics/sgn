
use strict;

use lib 't/lib';
use Test::More tests=>6;
use File::Slurp;
use Data::Dumper;

use Bio::Chado::Schema::Result::Stock::Stock;
use SGN::Test::Fixture;

use_ok('CXGN::Stock::StockBarcode');

my $test = SGN::Test::Fixture->new();
my $schema = $test->bcs_schema;

my @contents = read_file('t/data/stock/stock_barcode/file1.txt');

chomp(@contents);

foreach my $c (@contents){ 
#    $c=~s/^ //;
#    $c=~s/\r//g;
}

print join "\n", @contents;

my $sb = CXGN::Stock::StockBarcode->new({ schema => $schema });

$sb->parse(\@contents, 'CB', 'CO_334');

my $data = $sb->parsed_data();

#print STDERR Data::Dumper::Dumper($data);

is($data->{"Joe\t1\t1\t2012/11/12\t1"}->{38783}->{'CO_334:0000109'}->{value}, 0, 'check data point 1');
is($data->{"Joe\t1\t1\t2012/11/12\t2"}->{38783}->{'CO_334:0000108'}->{value}, 1, 'check data point 2');
is($data->{"Joe\t1\t1\t2012/11/12\t3"}->{38783}->{'CO_334:0000014'}->{value}, 5, 'check data point 3');
is($data->{"Joe\t1\t1\t2012/11/12\t4"}->{38784}->{'CO_334:0000109'}->{value}, 123, 'check data point 4');
is($data->{"Joe\t1\t1\t2012/11/12\t6"}->{38784}->{'CO_334:0000014'}->{value}, '4/10', 'check data point 5');
