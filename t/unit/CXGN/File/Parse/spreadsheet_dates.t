
# Date cells in an uploaded spreadsheet come back as ISO 8601 dates, whatever number format the cell
# displays them with, while numbers and text are returned as before.

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use Excel::Writer::XLSX;
use CXGN::File::Parse;

my $dir = tempdir(CLEANUP => 1);
my $file = "$dir/dates.xlsx";

my $workbook = Excel::Writer::XLSX->new($file);
my $sheet = $workbook->add_worksheet();
my $us_date = $workbook->add_format(num_format => 'm/d/yyyy');
my $short_date = $workbook->add_format(num_format => 'd-mmm-yy');
my $date_time = $workbook->add_format(num_format => 'm/d/yyyy h:mm');

$sheet->write_row(0, 0, [ 'observationunit_name', 'us_date', 'short_date', 'date_time', 'number', 'text' ]);
$sheet->write_string(1, 0, 'plot1');
$sheet->write_date_time(1, 1, '2026-03-24T', $us_date);
$sheet->write_date_time(1, 2, '2026-03-04T', $short_date);
$sheet->write_date_time(1, 3, '2026-03-24T14:30:05', $date_time);
$sheet->write_number(1, 4, 42.5);
$sheet->write_string(1, 5, '3/24/2026');
$workbook->close();

my $parsed = CXGN::File::Parse->new( file => $file )->parse();
is_deeply($parsed->{errors}, [], 'the spreadsheet parses without errors');

my $row = $parsed->{data}->[0];
is($row->{us_date}, '2026-03-24', 'a date cell formatted m/d/yyyy is returned as an ISO date');
is($row->{short_date}, '2026-03-04', 'a date cell formatted d-mmm-yy is returned as an ISO date');
is($row->{date_time}, '2026-03-24 14:30:05', 'a date and time cell keeps its time of day');
is($row->{number}, '42.5', 'a number is returned unchanged');
is($row->{text}, '3/24/2026', 'text that looks like a date is returned as typed');

done_testing();
