
use strict;
use Data::Dumper;

my $vcf_file = shift;

#print STDERR Dumper($vcf_file);

open(my $F, "<", $vcf_file) || die "Can't find file $vcf_file";

open(my $G, ">", $vcf_file.".hmp") || die "Can't open $vcf_file.hmp"; 

my $line;
while (<$F>) {
    my $line = $_;
    if ($line =~ m/^\#\#/) {
	print STDERR "SKIPPING ## lines...\n";
    }
    else {
	last;
    }
}

my $header = $line;

print STDERR $header;
chomp($header);

my @keys = split("\t", $header);
#print STDERR Dumper($keys[1]);

for(my $n=0; $n <@keys; $n++) {
    if ($keys[$n] =~ /\|CO\_/) {
	$keys[$n] =~ s/\|CO\_.*//;
    }
}
my @data = ();

my %nuconv = (
    'A/A' => 'A',
    'G/G' => 'G',
    'T/T' => 'T',
    'C/C' => 'C',
    'A/G' => 'R',
    'G/A' => 'R',
    'C/T' => 'Y',
    'T/C' => 'Y',
    'G/C' => 'S',
    'C/G' => 'S',
    'A/T' => 'W',
    'T/A' => 'W',
    'G/T' => 'K',
    'T/G' => 'K',
    'A/C' => 'M',
    'C/A' => 'M',
    './.' => 'N',
    );


while (<$F>) {
    chomp;
    my %line;    
    my @fields = split /\t/;
    
    for(my $n=0; $n <@keys; $n++) {
	if (exists($fields[$n]) && defined($fields[$n])) {
	    $line{$keys[$n]}=$fields[$n];
	}
    }
    push @data, \%line;
}

foreach my $line (@data) {
    my @formats = split /\:/, $line->{FORMAT};
    my $gtindex = 0;
    for(my $n =0; $n<@formats; $n++) {
	if ($formats[$n] eq 'GT') {
	    $gtindex=$n;
	}
    }
    
    for(my $gt = 0; $gt < @keys; $gt++) {
	my @scores = split /\:/, $line->{$gt};
	my $genotype;
	if ($scores[$gtindex] eq '0/0') {
	    $genotype = $line->{REF}."/".$line->{REF};
	}
	if ($scores[$gtindex] eq '0/1') {
	    $genotype = $line->{REF}."/".$line->{ALT};
	}
	if ($scores[$gtindex] eq '1/1') {
	    $genotype = $line->{ALT}."/".$line->{ALT};
	}
	    
	my $genotype_hmp = $nuconv{$genotype};
    }
}
   
    
close($F);
close($G);
