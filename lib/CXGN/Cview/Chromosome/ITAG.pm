
=head1 NAME

CXGN::Cview::Chromosome::ITAG - a chromosome class visualizing the ITAG assembly and BACs
           
=head1 DESCRIPTION

The ITAG chromosome object is populated by a flat file containing the assembly information in gff3 format that is generated as part of the ITAG annotation process. 

The name of the file is retrieved from the L<CXGN::ITAG::Release> object and parsed manually using a 'split' based parser.

=head1 AUTHOR(S)

Lukas Mueller <lam87@cornell.edu>

=head1 FUNCTIONS

This class implements the following functions:

=cut

use strict;

package CXGN::Cview::Chromosome::ITAG;

use File::Spec;
use CXGN::Cview::Chromosome;
use CXGN::Cview::Marker::AGP;

use base qw | CXGN::Cview::Chromosome |;


our $INTER_CONTIG_DISTANCE=100_000; # in bp
our $SCALE = 1000000; #= 1 MB

=head2 function new

  Synopsis:	my $c = CXGN::Cview::Chromosome::ITAG->new(
                 $chr_nr, $height, $x, $y, $file, $dbh)
  Arguments:	a chromosome identifier (may be non-numeric)
                the height of the chromosome in pixels
                the x offset
                the y offset
                the file with the contig information (gff3 format)
                a database handle (used to map contigs to the genetic
                  map).
    
  Returns:	an ITAG chromosome object
  Side effects:	
  Description:	

=cut

sub new {
    my $class = shift;
    
    my ($chr_nr, $height, $x, $y, $file, $dbh, $cache_dir) = @_;
    my $self = $class->SUPER::new($chr_nr, $height, $x, $y);
    
    $self->set_name($chr_nr);
    $self->set_units("MB");
    $self->rasterize(0);
    $self->set_rasterize_link("");
    $self->set_url("");
    $self->{dbh}= $dbh;

    if ($ENV{MOD_PERL}) { 
	$self->set_cache_dir($cache_dir);
    }
    else { 
	$self->set_cache_dir("/tmp");
    }
    # if no file was supplied or if the file does not exist,
    # return an empty chromosome
    #
    
    if (!$file || ! -e $file) { 
	die "Can't find file $file... ";
	return $self; 
    }

    $self->fetch($file);
    
    return $self;
    
}



=head2 add_bac

 Usage:        $c->add_bac($contig_name, $bac_name)
 Desc:         keeps a list of bac members for a contig,
               which is used to relate the contig to the 
               genetic map
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub add_bac {
    my $self = shift;
    my $contig_name = shift;
#    my $contig_start = shift;
#    my $bac_start = shift;
#    my $bac_end = shift;
    my $bac_name = shift;
#    my $coord = shift;

    push @{$self->{contig_members}->{$contig_name}}, $bac_name;

    #print STDERR "Added bac $bac_name to contig $contig_name\n";
#     my $bac_marker = CXGN::Cview::Marker::Physical->new($self);
#     my $bac_offset = $coord + (($bac_end - $bac_start)/2);
#     $bac_marker->set_offset($bac_offset/$SCALE);
#     $bac_marker->set_north_range(($bac_offset - $bac_start)/$SCALE);
#     $bac_marker->set_south_range(($bac_end - $bac_offset)/$SCALE);
#     $bac_marker->set_marker_name($bac_name);
#     $bac_marker->get_label()->set_name($bac_name);
#     $bac_marker->get_label()->set_url("/gbrowse/YYYYYY");
    
#     $self->add_marker($bac_marker);
#    print STDERR "Added a bac $bac_name at ".($bac_offset/$SCALE).",  end = ".(($coord + $bac_end)/$SCALE)."\n";
       
}

=head2 get_contig_members

 Usage:        my @contig_members = $c->get_contig_members($contig)
 Desc:         returns the contig members for contig $contig.
 Side Effects:
 Example:

=cut


sub get_contig_members { 
    my $self = shift;
    my $contig = shift;
    if (!defined($self->{contig_members})) { $self->{contig_members} = undef; }
    if (!defined($self->{contig_members}->{$contig})) { 
	$self->{contig_members}->{$contig} = [];
    }
    return @{$self->{contig_members}->{$contig}};
}
 
=head2 accessors get_cache_dir, set_cache_dir

 Usage:        $c->set_cache_dir($temp_dir)
 Desc:         this will be the directory where information
               for the ITAG chromosome will be cached. This 
               is normally set in the constructor.
 Property
 Side Effects:
 Example:

=cut

sub get_cache_dir {
  my $self = shift;
  return $self->{cache_dir}; 
}

sub set_cache_dir {
  my $self = shift;
  $self->{cache_dir} = shift;
}


=head2 add_contig
    
  Usage:        $c->add_contig($contig_start, $contig_end, $contig_name, $coord)
  Desc:         Adds a new contig to the ITAG chromosome.
  Ret:          nothing
  Args:         contig_start: the contig start coordinate
                contig_end: the contig end coordinate
                contig_name: name of the contig
                coord: the coordinate of the last contig
  Side Effects:
  Example:

=cut
    
sub add_contig {
    my $self = shift;
    my $contig_start = shift;
    my $contig_end = shift;
    my $contig_name = shift;
    my $coord = shift;

    my $offset = $coord + (($contig_end - $contig_start) /2);
    
    #print STDERR "Adding contig $contig_name...\n";

    my $contig_marker = CXGN::Cview::Marker::Physical->new($self);
    $contig_marker->set_offset(($offset)/$SCALE);
    $contig_marker->set_hilite_chr_region(1);
    $contig_marker->set_north_range((($contig_end-$contig_start)/2)/$SCALE);
    $contig_marker->set_south_range((($contig_end-$contig_start)/2)/$SCALE);
    $contig_marker->set_marker_name($contig_name);
    $contig_marker->get_label()->set_name($contig_name);
    $contig_marker->set_color(255,0,0);
#    $contig_marker->set_url("/gbrowse/gbrowse/ITAG_devel_genomic/?name=$contig_name");
    $self->{contigs}->{$contig_name}=$contig_marker; # keep a hash for fast access.
    $self->add_marker($contig_marker);
    #print STDERR "Added new contig: $contig_name offset=".(($offset)/$SCALE)." \n";    
    
}
    

=head2 fetch

 Usage:        $c->fetch()
 Desc:         reads in the file
 Ret:
 Args:
 Side Effects: generates a cachefile if it does not yet exist.
 Example:

=cut

sub fetch {
    my $self = shift;
    my $file = shift;

    #print STDERR "CACHEFILE = $file\n\n\n";
    
    my $assoc = CXGN::Genomic::BACMarkerAssoc->new($self->{dbh});    
    my $cachefile = File::Spec->catfile($self->get_cache_dir(), "itag_chr".$self->get_name());
    if (-e $cachefile) { 
	open (my $C, "<$cachefile") || die "Can't open file '$cachefile'"; 
	
	# the first line is the length of the chromosome
	#
	my $length = <$C>;
	chomp($length);
	$self->set_length($length);
	
	while (<$C>) { 
	    chomp;
	    my ($contig_name, $marker_id, $url, $offset, $north_range, $south_range, $tooltip, @color) = split /\t/;
	    
	    my $contig_marker = CXGN::Cview::Marker::Physical->new($self);
	    $contig_marker->set_offset($offset);
	    $contig_marker->set_hilite_chr_region(1);
	    $contig_marker->set_north_range($north_range);
	    $contig_marker->set_south_range($south_range);
	    $contig_marker->set_id($marker_id);
	    $contig_marker->set_marker_name($contig_name);
	    $contig_marker->get_label()->set_name($contig_name);
	    $contig_marker->set_tooltip($tooltip);
	    $contig_marker->set_color(255,0,0);
	    $contig_marker->set_url($url);
	    $self->add_marker($contig_marker);
	    if ($offset < $length) { $length = $offset; }
	}
	
	close($C);
    }
    else { 
	# generate new cache file if it doesn't exist
	#
	open (my $C, ">$cachefile") || die "Can't open file '$cachefile' for writeing...";
	open (my $ITAG, "<$file") || die "Can't open $file\n";
	
	# parse gff3 file
	#
	my ($coord, $contig_start, $contig_end) = ();
	my %contigs = (); # hash of listref with bacname, start, end
	my %contig_coords = (); # has of contig-based bac start and ends 
	my @contig_order = (); # the order in which the contigs should appear
	my ($contig_name, $itag_name, $type, $c_start, $c_end, $dot1, $dir, $dot2, $info, $bac_name, $bac_start, $bac_end) = ();
	while (<$ITAG>) { 
	    chomp;
	    
	    next if /^\s*\#/;
	    
	    my $current_chr;
	    if (/^C(\d+)/) { 
		$current_chr = $1;
	    }
	    #print STDERR "Current chr: $current_chr\n";
	    if ($current_chr != $self->get_name()) { 
		#print STDERR "Skipping chr $current_chr because not ".$self->get_name()."\n";
		#print STDERR ".";
		next; 
	    }
	    	    
	    ($contig_name, $itag_name, $type, $c_start, $c_end, $dot1, $dir, $dot2, $info) = split /\t/;
	    
	    ($bac_name, $bac_start, $bac_end) = split /\s+/, $info;
	    if ($bac_name =~ /^Name=(.*?)\;.*/) { 
		$bac_name = $1;
	    }
	    	    
	    push @{$contigs{$contig_name}}, [$bac_name, $bac_start, $bac_end];
	    push @{$contig_coords{$contig_name}}, [$bac_name, $c_start, $c_end];
	}


	# sort the contigs by their position as represented by their numbering
	#
	my @contig_order = sort { my ($x, $y) = (); if ($a=~/contig(\d+)/i) { $x = $1; } if ($b=~/contig(\d+)/) { $y = $1; } return $x <=> $y; } (keys %contigs);
	
	#foreach my $c (@contig_order) { 
	#    print STDERR "Contig: $c\n";
	#}
	my $old_contig_name = "";

	foreach my $c (@contig_order) { 
	    
		$contig_start = $contig_coords{$c}->[0]->[1];
		
		$contig_end   = $contig_coords{$c}->[-1]->[2];
		
		#print STDERR "Contig start $contig_start. Contig end $contig_end.\n";

		$self->add_contig($contig_start, $contig_end, $c, $coord);
		
		foreach my $b (@{$contigs{$c}}) { 
		    my ($bac_name, $bac_start, $bac_end) = @$b;

		    #print STDERR "    $bac_name $bac_start $bac_end\n";
		    $self->add_bac($c, $bac_name);
		    #$coord += $bac_end;
		}
	   
	    $coord = $coord + $contig_end + $INTER_CONTIG_DISTANCE;
	}
	
	$self->set_length(($coord)/$SCALE);	  
	
	# print to cachefile
	#
	#my $assoc = CXGN::Genomic::BACMarkerAssoc->new($self->get_dbh());    
	open (my $C, ">$cachefile") || die "Can't open file '$cachefile'";


	# the first line is the length of the chromosome...
	print $C $self->get_length()."\n";

	foreach my $m ($self->get_markers()) { 
	    
	    my @members = $self->get_contig_members($m->get_marker_name());
	    my $tooltip = $m->get_name()." (".(scalar(@members))." BACs) [ ".(join ", ", @members)."]";
	    foreach my $bac (@members) { 
		my $clone = CXGN::Genomic::Clone->retrieve_from_clone_name($bac);
		my @markers = $assoc->get_markers_with_clone_id($clone->clone_id());
		if (@markers > 0) { 
		    $m->set_id($markers[0]->{marker_id});
		    $tooltip .= " (".$markers[0]->{marker_name}.")";
		}
		
	    }
	    $m->set_tooltip($tooltip);
	    
	    print $C join "\t", ( 
				  $m->get_label()->get_name(), # contig name
				  $m->get_id(),       # marker id
				  $m->get_url(),
				  $m->get_offset(),
				  $m->get_north_range(),
				  $m->get_south_range(),
				  $m->get_tooltip(),
				  $m->get_color(),

				  );
	    
	    print $C "\n";
	}   
	
	close($ITAG);
	close($C);
	
    }

}

    
    

return 1;
