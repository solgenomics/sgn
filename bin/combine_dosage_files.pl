
use strict;

my @files = shift;

use Data::Dumper;

use CXGN::GenotypeIO;

my @files = @ARGV;

my @io = ();

foreach my $f (@files) {
    print STDERR "Opening file $f... ";
    my $gtio = CXGN::GenotypeIO->new( { file => $f, format=>"dosage_transposed"});
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
    print "\t".$m;
}
print "\n";


foreach my $name (sort keys %all_accs) { 
    print $name;
    foreach my $m (sort keys %all_markers) { 
	print "\t".$all_accs{$name}->{$m};
    }
    print "\n";
}


print STDERR "Done.\n";
