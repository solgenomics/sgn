#!/usr/bin/env perl

=head1 NAME

script_factory_blupf90.pl - run an Analysis Pipeline recipe on the BLUPF90+ engine (no R)

=head1 SYNOPSIS

  perl script_factory_blupf90.pl <phenotype_file> <recipe_json> <output_json> [exclusions_json] [output_prefix] \
       [--pedigree=<file>] [--repeated=<file>] [--genotypes=<file>] [--blupf90-dir=<dir>]

Same arguments as R/script_factory/script_factory_pipeline.R; --genotypes is
the dosage matrix of a genotyping protocol (bin/script_factory_genotypes.pl)
for the genomic (G) and single-step (H) models. blupf90+ is
looked up in --blupf90-dir, then in $BLUPF90_DIR, then in the PATH. The
number of models fitted at the same time is $BLUPF90_PARALLEL (default:
number of cores - 1, at most 7).

=head1 DESCRIPTION

Command of an Analysis Pipeline job when the model engine is BLUPF90+.
See L<CXGN::BLUPF90::Pipeline>.

=head1 AUTHOR

Chris Simoes <ccs263@cornell.edu>

=cut

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use JSON::XS;
use CXGN::BLUPF90::Pipeline;

my %named;
my @args;
foreach my $a (@ARGV) {
    if ($a =~ /^--(pedigree|repeated|genotypes|blupf90-dir)=(.*)$/) { $named{$1} = $2; }
    else { push @args, $a; }
}
if (@args < 3) {
    print STDERR "Usage: script_factory_blupf90.pl <phenotype_file> <recipe_json> <output_json> [exclusions_json] [output_prefix] [--pedigree=<file>] [--repeated=<file>]\n";
    exit(2);
}
my ($pheno, $recipe_file, $out, $excl, $prefix) = @args;
my $recipe = eval { open(my $F, '<', $recipe_file) or die "Cannot open $recipe_file\n"; local $/; my $j = <$F>; close($F); decode_json($j) };
if (!$recipe) {
    print STDERR "Error: invalid recipe file ($@)\nExecution halted\n";
    exit(1);
}
my $p = CXGN::BLUPF90::Pipeline->new({
    phenotype_file => $pheno, recipe => $recipe, output_file => $out,
    (defined($excl) && $excl ne '' ? (exclusions_file => $excl) : ()),
    (defined($prefix) && $prefix ne '' ? (output_prefix => $prefix) : ()),
    ($named{pedigree} ? (pedigree_file => $named{pedigree}) : ()),
    ($named{repeated} ? (repeated_file => $named{repeated}) : ()),
    ($named{genotypes} ? (genotypes_file => $named{genotypes}) : ()),
    ($named{'blupf90-dir'} ? (bin_dir => $named{'blupf90-dir'}) : ()),
});
exit($p->run() ? 0 : 1);
