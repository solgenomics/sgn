use strict;
use warnings;

use Test::More tests => 7;
use FindBin;
use File::Spec::Functions;

use_ok('SGN::Genefamily');

my $test_dir = 't/data/genefamily_data';

my $gf = SGN::Genefamily->new( files_dir => $test_dir,
			       build   => 'test',
			       name      => 'family_0'
    );

is($gf->name(), "family_0", "name test");
is($gf->build(), "test", "dataset test");
is($gf->files_dir(), $test_dir, "files_dir test");
is($gf->get_path(), catdir($test_dir,'test'), "get_path test");
my $aln = $gf->get_alignment();
like($aln, qr/KLSILKDV-----------NDKSCV/, "alignment test");

my $fasta = $gf->get_fasta();
$fasta =~ s/\n//g;
like($fasta, qr/KLSILKDVNDKSCV/, "fasta test");



