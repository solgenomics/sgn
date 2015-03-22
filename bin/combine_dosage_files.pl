
use strict;

use Data::Dumper;
use Getopt::Std;
use CXGN::GenotypeIO;

our ($opt_r, $opt_o); # -r: fix r headers -o: outfile
getopts('ro:');

my @files = @ARGV;

my @io = ();
open(my $OUT, ">", $opt_o) || die "Can't open outfile $opt_o";

foreach my $f (@files) {
    print STDERR "Opening file $f... ";
    my $gtio = CXGN::GenotypeIO->new( { file => $f, format=>"dosage_transposed", fix_r_headers => $opt_r });
    push @io, $gtio;
    
    print STDERR "Done.\n";
}

my %all_markers;
my %all_accs;

foreach my $io (@io) { 
    print STDERR "processing file ".$io->plugin->file().".\n";
    while (my $gt= $io->next()) { 
	my $name = $gt->name();
	my $markers = $gt->markers();
	foreach my $m (@$markers) { 
	    $all_markers{$m}++;
	}
	my $scores = $gt->rawscores();
	#print STDERR Dumper($scores);
	foreach my $k (keys %$scores) { 
	    #print "Adding score $scores->{$k} for marker $k to accession $name...\n";
	    $all_accs{$name}->{$k} = $scores->{$k};
	}
    }
}


foreach my $m (sort keys %all_markers) { 
    print $OUT "\t".$m;
}
print $OUT "\n";


foreach my $name (sort keys %all_accs) { 
    print $OUT $name;
    foreach my $m (sort keys %all_markers) { 
	print $OUT "\t".$all_accs{$name}->{$m};
    }
    print $OUT "\n";
}


print STDERR "Done.\n";
