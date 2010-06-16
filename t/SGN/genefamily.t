
use strict;
use warnings;

use Test::More tests=>7;

use_ok('SGN::Genefamily');

my $gf = SGN::Genefamily->new( files_dir => 'genefamily_data', 
			       dataset   => 'test', 
			       name      => 'family_0'
    );

is($gf->name(), "family_0", "name test");
is($gf->dataset(), "test", "dataset test");
is($gf->files_dir(), "genefamily_data", "files_dir test");
is($gf->get_path(), "genefamily_data/test", "get_path test");
my $aln = $gf->get_alignment();
like($aln, qr/KLSILKDV-----------NDKSCV/, "alignment test");

my $fasta = $gf->get_fasta();
$fasta =~ s/\n//g;
like($fasta, qr/KLSILKDVNDKSCV/, "fasta test");



