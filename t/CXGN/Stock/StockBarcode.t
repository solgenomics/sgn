
use strict;

use lib 't/lib';
use Test::More tests=>6;
use File::Slurp;

use Bio::Chado::Schema::Result::Stock::Stock;
use SGN::Test::WWW::Mechanize;

use_ok('CXGN::Stock::StockBarcode');

my $test = SGN::Test::WWW::Mechanize->new();
my $schema = $test->context->dbic_schema('Bio::Chado::Schema');

my @contents = read_file('t/data/stock/stock_barcode/file1.txt');

chomp(@contents);

foreach my $c (@contents){ 
#    $c=~s/^ //;
#    $c=~s/\r//g;
}

print join "\n", @contents;

my $sb = CXGN::Stock::StockBarcode->new({ schema => $schema });

$sb->parse(\@contents, 'CB', 'CO');

my $data = $sb->parsed_data();

is($data->{"Joe\t1\t1\t2012/11/12"}->{38783}->{'CO:0000109'}->{value}, 0, 'check data point 1');
is($data->{"Joe\t1\t1\t2012/11/12"}->{38783}->{'CO:0000108'}->{value}, 1, 'check data point 2');
is($data->{"Joe\t1\t1\t2012/11/12"}->{38783}->{'CO:0000014'}->{value}, 5, 'check data point 3');
is($data->{"Joe\t1\t1\t2012/11/12"}->{38784}->{'CO:0000109'}->{value}, 123, 'check data point 4');
is($data->{"Joe\t1\t1\t2012/11/12"}->{38784}->{'CO:0000014'}->{value}, '4/10', 'check data point 5');
