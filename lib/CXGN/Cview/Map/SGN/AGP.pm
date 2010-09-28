
use strict;
use warnings;

package CXGN::Cview::Map::SGN::AGP;


use File::Spec;
use CXGN::Cview::Chromosome::AGP;
use CXGN::Cview::Map::Tools;
use CXGN::Genomic::Clone;
use CXGN::Genomic::BACMarkerAssoc;

use base qw | CXGN::Cview::Map |;

our $ENDMARKER = "END OF DRAFT";

sub new { 
    my $class = shift;
    my $dbh = shift;
    my $id = shift;
    my $args = shift;

    my $self = $class->SUPER::new($dbh);

    $self->set_id($id);
    $self->set_chromosome_names( "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12");
    my @lengths = ();


    $self->set_chromosome_count(12);
    $self->set_short_name($args->{short_name});
    $self->set_long_name($args->{long_name});
    $self->set_abstract($args->{abstract});
    $self->set_temp_dir($args->{temp_dir} || "/tmp");
    $self->set_units("MB");

    # we need to cache the chromosome length information on the filesystem...
    $self->cache_chromosome_lengths();
    #print STDERR "FILENAMES = ". (join " ", (map  {$_.":".$self->get_files()->{$_} } keys %{$self->get_files()}) ) ."\n";
    #print STDERR "Constructor: generating AGP chr ".$self->get_name()."\n";

    return $self;
}

sub get_chromosome { 
    my $self   = shift;
    my $chr_nr = shift;

    if (exists($self->{chr}->{$chr_nr})) { 
	return $self->{chr}->{$chr_nr};
    }

    $self->get_files();
    
    #print STDERR "Getting associated markers...\n";
    my $assoc = CXGN::Genomic::BACMarkerAssoc->new($self->get_dbh());
   
    #print STDERR "get_chromosome with $chr_nr. File: ".($self->get_files()->{$chr_nr})."\n";

    my $chromosome =  CXGN::Cview::Chromosome::AGP->new($chr_nr, 1, 1, 1, $self->get_files()->{$chr_nr});
    if (!$chromosome->get_markers()) { 
	$self->append_messages("No AGP file seems to be available for chr $chr_nr. ");
    }

    my $files = $self->get_files();
    #print STDERR "FILE: $files->{$chr_nr}\n";
    if ($files->{$chr_nr}=~/sgn/) { 
	$self->append_messages("This AGP map was automatically generated at SGN because no AGP file was submitted by the sequencing partner. It may be missing BACs or represent the information incorrectly. It is given as an approximate working reference");
    }  

    $chromosome->rasterize(0);
    $chromosome->set_rasterize_link("");

    #print STDERR "Getting bac names and clone_ids...\n";

    foreach my $bac ($chromosome->get_markers()) { 
	my $clone = CXGN::Genomic::Clone->retrieve_from_clone_name($bac->get_label()->get_name());
	$bac->get_label()->set_url($self->get_marker_link($clone->clone_id()));
#	$bac->set_label_side("left");
#	$bac->get_label()->align_right();
	my @markers = $assoc->get_markers_with_clone_id($clone->clone_id());
	if (@markers) { 
	    $bac->set_id($markers[0]->{marker_id});
	}
	$bac->set_tooltip($bac->get_marker_name());
	$bac->hide_label();
    }
    
    $chromosome->set_name();
    $chromosome->set_caption();
    $chromosome->set_height(100);
    
    return $chromosome;
}

sub get_overview_chromosome { 
     my $self = shift;
     my $chr_nr = shift;

     my $chr = $self->get_chromosome($chr_nr);
     
     foreach my $m ($chr->get_markers()) { 
	 $m->hide_label();
	 $m->set_show_tick(0);
	 $m->set_url("");
     }
     if (!$chr->get_markers()) { 
#	 $chr->set_url("");
     }
     
     return $chr;
 }


sub get_chromosome_section { 
    my $self = shift;
    my $chr_nr = shift;
    my $start = shift;
    my $end = shift;
    my $comparison = shift;
    
    my $chr = $self->get_chromosome($chr_nr);
    
    $chr -> set_section($start, $end);
    
    foreach my $m ($chr->get_markers()) { 
	$m->unhide();
	if ($comparison) { $m->get_label()->set_hidden(1); }
	$m->set_hilite_chr_region(1);
    }
    return $chr;
}




sub show_stats { 
    return 1;
}


=head2 accessors set_files, get_files

  Property:	a hashref that stores chromosme name keys and file names
                as the hash values.
  Setter Args:	
  Getter Args:	
  Getter Ret:	
  Side Effects:	
  Description:	

=cut

sub get_files { 
    my $self=shift;
    
    if (exists($self->{files}) && defined($self->{files})) { 
	return $self->{files};
    }

    my $files_dir = "/data/prod/public/tomato_genome/agp";

    my %unversioned_filenames  = ();

    foreach my $chr (1..12) { 
	my $filename = File::Spec->catfile($files_dir, "chr".(sprintf '%02d', $chr).".v*.agp");
	#print STDERR "Unversioned filename: $filename\n";
	chomp($filename);
	$unversioned_filenames{$chr}  = $filename;
	
    }

    my %versioned_filenames = ();
    my %sgn_files = ();
    foreach my $k (keys %unversioned_filenames) { 

	$sgn_files{$k}= File::Spec->catfile($files_dir, "sgn_chr".(sprintf "%02d", $k).".agp");
	#print STDERR "SGN FILE: $sgn_files{$k}\n";
	$versioned_filenames{$k} = $self->get_filename($unversioned_filenames{$k});



	# if the projects have not supplied a file, let's look for an SGN generated 
	# file that is prefixed with "sgn_".
	#
	if (!-e $versioned_filenames{$k}) { 
	    if ( -e $sgn_files{$k}) { 
		$versioned_filenames{$k} = $sgn_files{$k};
		#print STDERR "USING SGN FILE: $sgn_files{$k}\n";
	    }
	    else { 
		#print STDERR "No file found for chr $k\n"; 
		
	    }
	}
	#print STDERR "Final file used: $versioned_filenames{$k}\n";
    }
    
    $self->set_files(\%versioned_filenames);

    return $self->{files};



}

sub set_files { 
    my $self=shift;
    $self->{files}=shift;
}

sub get_marker_type_stats { 
    my $self = shift;
    
}

sub get_map_stats { 
        return "Only fully sequenced BACs are shown on this map.";
}

sub get_marker_count { 
    my $self = shift;
    my $chr_nr = shift;
    
    my $marker_count = 0;
    if (exists($self->get_files()->{$chr_nr}) && $self->get_files()->{$chr_nr}) { 
	open (my $F, '<', $self->get_files()->{$chr_nr}) || die "Can't open agp definition file for chr $chr_nr [ ".$self->get_files()->{$chr_nr}." ] : $!";
	while (<$F>) { 
	    chomp;
	    my ($project, $start, $end, $count, $dir, $clone_name) = split /\t/;

	    if ($dir=~/R|F/i) { 
		$marker_count++;
	    }

	}
    }
    return ($marker_count);
    
}

# an internal function to calculate chromosome lengths. Not to be confused with 
#  
sub _determine_chromosome_length { 
    my $self = shift;
    my $chr_nr = shift;
    
    my $longest = 1; # prevent division by zero errors. 1 is very small for practical purposes here.
    if (exists($self->get_files()->{$chr_nr}) && $self->get_files()->{$chr_nr}) { 
	open (my $F, '<', $self->get_files()->{$chr_nr}) || die "Can't open agp definition file for chr $chr_nr [ ".$self->get_files()->{$chr_nr}." ] : $!";

	while (<$F>) { 
	    chomp;
	     if (/$ENDMARKER/) { 
		last();
	    }
	    my ($project, $start, $end) = split /\t/;

	   
	    if ($end > $longest) { 
		$longest=$end;
	    }
	    
	}
    }
    return ($longest/1000000);
    
}
	    
sub get_filename { 
    my $self = shift;
    my $filename = shift;
    my @files = `ls -t $filename`;
    #print STDERR "unversioned name = $filename. versioned name = $files[0]\n";
    chomp($files[0]);
    return $files[0];
}

# show no markers on the overview
sub collapsed_marker_count { 
    return 0;
}

sub can_zoom { 
    return 1;
}

sub cache_chromosome_lengths { 
    my $self  =shift;
    my $chr_len_cache = File::Spec->catfile($self->get_temp_dir(), "agp_chr_len_cache.txt");

    my $LENCACHE;
    my @lengths = ();
    if ( -e $chr_len_cache ) { 
	open($LENCACHE, '<', $chr_len_cache) or die "Can't open the agp cache $chr_len_cache: $!";
	while (<$LENCACHE>) { 
	    chomp;
	    my ($chr, $len) = split /\t/;
	    push @lengths, $len;
	}
	$self->set_chromosome_lengths(@lengths);
	close($LENCACHE);
	return;
    }
    open ($LENCACHE, '>', $chr_len_cache) or die "Can't open the agp chr len cache file $chr_len_cache: $!";
    for my $chr_nr ($self->get_chromosome_names()) { 
        my $len = $self->_determine_chromosome_length($chr_nr);
        print $LENCACHE "$chr_nr\t$len\n";
        push @lengths, $len;
    }
    close($LENCACHE);
    $self->set_chromosome_lengths(@lengths);
}

=head2 get_chromosome_connections

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_chromosome_connections {
    my $self = shift;
    my $chr_nr = shift;
    my $map_version_id = CXGN::Cview::Map::Tools::find_current_version($self->get_dbh(), CXGN::Cview::Map::Tools::current_tomato_map_id());

    my $connections = { map_version_id => $map_version_id,
			lg_name => $chr_nr,
			marker_count => "?",
			short_name => "F2-2000"

			};
    return ($connections);
    
}

    



return 1;
