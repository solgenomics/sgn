use strict;
use warnings;

use Test::More;
use File::Temp;
use CXGN::BrAPI::FileResponse;

# BrAPI v1 csv and tsv files must keep a value 0 (a measured 0 or a
# genotype dosage 0). Only an undefined value becomes an empty cell.

my @data = (
    ['marker', 'markerprofileDbId', 'genotype'],
    ['S1', '610', '0'],
    ['S2', '610', 0],
    ['S3', '610', '2'],
    ['S4', '610', undef],
    ['S5', '610', ''],
);

sub write_file {
    my $format = shift;
    my $tmp = File::Temp->new();
    my $response = CXGN::BrAPI::FileResponse->new({
        absolute_file_path => $tmp,
        absolute_file_uri => 'http://localhost/file',
        format => $format,
        data => \@data,
    });
    my @files = $response->get_datafiles();
    is_deeply(\@files, ['http://localhost/file'], "$format returns the file uri");
    open(my $fh, '<', $tmp->filename) or die "cannot read $tmp: $!";
    local $/;
    my $content = <$fh>;
    close($fh);
    return $content;
}

is(write_file('csv'), join('',
    qq{"marker","markerprofileDbId","genotype"\n},
    qq{"S1","610","0"\n},
    qq{"S2","610","0"\n},
    qq{"S3","610","2"\n},
    qq{"S4","610",""\n},
    qq{"S5","610",""\n},
), 'csv keeps 0 and writes undef and empty values as empty cells');

is(write_file('tsv'), join('',
    "marker\tmarkerprofileDbId\tgenotype\n",
    "S1\t610\t0\n",
    "S2\t610\t0\n",
    "S3\t610\t2\n",
    "S4\t610\t\n",
    "S5\t610\t\n",
), 'tsv keeps 0 and writes undef and empty values as empty cells');

done_testing();
