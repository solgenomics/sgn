
=head1 NAME

CXGN::Cview::Chromosome::AGP - a chromosome class visualizing the AGP file           
           
=head1 DESCRIPTION

The AGP chromosome object is populated by flat files that the sequencing projects upload to SGN and that are available from the SGN FTP site. 

The constructor looks whether it has a locally cached copy of the AGP file, and uses it if it is available. Otherwise, it invokes wget to get a fresh copy fromthe FTP site.

This class inherits from CXGN::Cview::Chromosome.

=head1 AUTHOR(S)

Lukas Mueller <lam87@cornell.edu>

=head1 FUNCTIONS

This class implements the following functions:

=cut

use strict;

package CXGN::Cview::Chromosome::AGP;

use File::Spec;
use CXGN::Cview::Chromosome;
use CXGN::VHost;
use CXGN::Cview::Marker::AGP;

use base qw | CXGN::Cview::Chromosome |;


=head2 function new

  Synopsis:	my $agp = CXGN::Cview::Chromosome::AGP->new(
                   $chr_nr, $height, $x, $y, $agp_file);
  Arguments:	* a chromosome id (usually a int, but can by anything)
                * the height of the chromosome in pixels [int]
                * the horizontal offset in pixels [int]
                * the vertical offset in pixels [int]
                * the filename of the file containing the agp info.
  Returns:	a CXGN::Cview::Chromosome::AGP object
  Side effects:	generates some cache files on disk
  Description:	this parses the file $agp_file and creates a new AGP
                object. For faster access, cache files are generated
                in a temp location.

=cut

sub new {
    my $class = shift;
    my ($chr_nr, $height, $x, $y, $agp_file) = @_;
    my $self = $class->SUPER::new($chr_nr, $height, $x, $y);
    
    $self->set_name($chr_nr);
    $self->set_units("MB");
    $self->rasterize(0);
    $self->set_rasterize_link("");
    $self->set_url("");
    # if no file was supplied or if the file does not exist,
    # return an empty chromosome
    #

    if (!$agp_file || ! -e $agp_file) { return $self; }

    $self->fetch($agp_file);

    return $self;

}

=head2 fetch

 Usage:        $agp->fetch($file);
 Desc:         loads the AGP object from the file $file  
               this function is called by the constructor
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub fetch { 
    my $self = shift;
    my $agp_file = shift;

    $self->set_height(50);
    $self->set_length(1);
    
    #print STDERR "Constructor: generating AGP chr ".$self->get_name()."\n";

    my $AGP = undef;
    
    open ($AGP, "<$agp_file") || die "Can't open $agp_file\n";

    my $largest_offset = 0;
    while (<$AGP>) { 
	chomp;
	last if /END OF DRAFT/;
	next if /^\s*\#/;
	
	my ($project_name, $start, $end, $count, $dir, $size_or_clone_name, $overlap_or_type, $clone_size_or_yesno, $orientation) = split /\t/;
	my $gap_size = 0;
	my $clone_name = "";
	if ($size_or_clone_name =~ /^\d+$/) { 
	    $gap_size = $size_or_clone_name;
	}
	else { 
	    $clone_name = $size_or_clone_name;
	}
	
	my $overlap = 0;
	my $type = "";
	if ($overlap_or_type =~ /clone|contig/i) { 
	    $type=$overlap_or_type;
	}
	else { 
	    $overlap = $overlap_or_type;
	}

	my $yesno = "";
	my $clone_size = 0;
	if ($clone_size_or_yesno =~/Y|N/i) { 
	    $yesno = $clone_size_or_yesno;
	}
	else { 
	    $clone_size = $clone_size_or_yesno;
	}	

	if ($dir!~/N/i) { 
	    # if dir is not N (meaning it is R or F), then add
	    # a marker. Otherwise we deal with a gap.
	    #print STDERR "READ AGP file line: $start\t$end\$count\t$dir\n";
	    my $bac = CXGN::Cview::Marker::Physical->new($self);
	    $bac->set_hilite_chr_region(1);
	    my $offset = ($start+$end)/2;

	    # convert numbers to MBases
	    #
	    my $MB = 1e6;
	    $offset = $offset / $MB;
	    $start = $start / $MB;
	    $end = $end / $MB ;
	    
	    if ($offset > $largest_offset) { $largest_offset = $offset; }
	 
	    $bac->set_offset($offset);
	    $bac->set_north_range($offset-$start);
	    $bac->set_south_range($end-$offset);
	    $bac->set_marker_name($clone_name);
	    $bac->get_label()->set_name($clone_name);
	    # to do: $bac->set_url();

	    
	    $self->add_marker($bac);
	   
	    #print STDERR "Added a bac at $offset, north = ".($offset-$start).", end = ".($end-$offset)."\n";
	}
	else { 
	    # also include gaps in the calculation of the largest offset
	    my $gap_offset = int(($start+$end)/2);
	    $gap_offset = $gap_offset/1000000;
	    
	    if ($gap_offset>$largest_offset) { 
		$largest_offset = $gap_offset;
	    }
	}
    }
    close($AGP);
    
    
    $self->set_length($largest_offset);
}
 
return 1;
