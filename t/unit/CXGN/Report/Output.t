
# Tests for CXGN::Report::Output: files written by Report Factory scripts

use strict;
use warnings;
use Test::More;
use File::Temp qw | tempdir |;
use File::Slurp qw | read_file write_file |;
use JSON;

use CXGN::Report::Output;

my $dir = tempdir(CLEANUP => 1);

my $out = CXGN::Report::Output->new({ directory => $dir, basename => 'rep', title => 'My report', preview_rows => 3 });
$out->add_summary('Rows', 5)->add_summary('Share', 0.5, 'half');
$out->add_chart({ title => 'By type', labels => [ 'a', 'b' ], values => [ 2, 3 ] });
$out->add_chart({ title => 'broken' });    # ignored
$out->add_note('A note');
$out->add_note('');                          # ignored
$out->set_input(trials => 2);
$out->add_table({ name => 'Data/main', columns => [ 'name', 'value' ], rows => [ map { [ "plot_$_", $_ ] } 1 .. 5 ] });
$out->add_table({ name => 'Map', columns => [ 'x' ], rows => [ [ '007' ] ] });
my $files = $out->write();

ok(-s "$dir/rep.xlsx", 'xlsx written');
ok(-s "$dir/rep_data_main.csv", 'csv of first table');
ok(-s "$dir/rep_map.csv", 'csv of second table');
ok(-s "$dir/rep.results.json", 'results written');
is(scalar(@$files), 4, 'four files returned');

my @csv = read_file("$dir/rep_data_main.csv");
is(scalar(@csv), 6, 'csv has header and all rows');
is($csv[0], "name,value\n", 'csv header');

my $r = decode_json(read_file("$dir/rep.results.json", binmode => ':raw'));
is($r->{title}, 'My report', 'title');
is(scalar(@{ $r->{summary} }), 2, 'two summary values');
is($r->{summary}->[1]->{hint}, 'half', 'hint kept');
is(scalar(@{ $r->{charts} }), 1, 'invalid chart ignored');
is_deeply($r->{notes}, [ 'A note' ], 'empty note ignored');
is($r->{inputs}->{trials}, 2, 'input summary');
is($r->{tables}->[0]->{total_rows}, 5, 'total rows');
is(scalar(@{ $r->{tables}->[0]->{rows} }), 3, 'preview limited');
ok($r->{tables}->[0]->{truncated}, 'truncated flag');
ok(!$r->{tables}->[1]->{truncated}, 'small table not truncated');
is($r->{tables}->[1]->{rows}->[0]->[0], '007', 'leading zeros kept');

# a single table gets <basename>.csv
my $one = CXGN::Report::Output->new({ directory => "$dir/", basename => 'single' });
$one->add_table({ name => 'Only', columns => [ 'a' ], rows => [] });
$one->write();
ok(-e "$dir/single.csv", 'single table csv named after the report');

eval { $one->add_table({ columns => [ 'a' ] }) };
like($@, qr/needs a name/, 'table without name refused');

# inputs written by the runner
write_file("$dir/ids.txt", "12\n 13 \nabc\n\n14\n");
is_deeply([ CXGN::Report::Output::read_ids("$dir/ids.txt") ], [ 12, 13, 14 ], 'read_ids keeps numeric ids');
is_deeply([ CXGN::Report::Output::read_ids(undef) ], [], 'read_ids without a file');
is_deeply([ CXGN::Report::Output::read_ids("$dir/none.txt") ], [], 'read_ids with a missing file');

done_testing();
