
use strict;

use Hash::Case::Preserve;

my $vcf_file = shift;
my $equivalence_file = shift;


open(my $E, "<", $equivalence_file) || die "Can't open $equivalence_file\n";

tie my %ids, 'Hash::Case::Preserve';
while (<$E>) {
    chomp;

    my ($original_id, $modified_id, $new_id, $match_type, $stock_type) = split /\t/;
    $ids{$original_id} = $new_id;
}

close($E);

open(my $V, "<", $vcf_file) || die "Can't open $vcf_file\n";

while (<$V>) {
    chomp();

    if ($_ =~ m/^\#CHROM/) {
	print STDERR "Parsing ids in vcf file...\n";
	my @F = split /\t/;
	my $count = 0;
	foreach my $f (@F) {
	    $count++;
	    if (exists($ids{$f}) && ($ids{$f} ne $f)) {
		print STDERR "replace $f with $ids{$f} ($count), ";
		$f = $ids{$f};
	    }
	}
	my $line = join("\t", @F);
	print "$line\n";
    }
    else {
	print $_."\n";
    }
}
    
    
