
use strict;

package CXGN::Cview::Map::SGN::ITAG;

use File::Spec;
use CXGN::ITAG::Release;
use CXGN::Cview::Chromosome::ITAG;
use CXGN::Cview::Map::Tools;
use CXGN::Genomic::Clone;
use CXGN::Genomic::BACMarkerAssoc;

use base qw | CXGN::Cview::Map | ;

sub new { 
    my $class = shift;
    my $dbh = shift;
    my $id = shift;

    my $self = $class->SUPER::new($dbh);

    $self->set_id($id);

    $self->set_chromosome_names( "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12");
    print STDERR "ITAG map constructor...\n";

    #print STDERR "FILENAMES = ". (join " ", (map  {$_.":".$self->get_files()->{$_} } keys %{$self->get_files()}) ) ."\n";
    #print STDERR "Constructor: generating AGP chr ".$self->get_name()."\n";

    $self->set_chromosome_count(12);
    $self->set_short_name("Tomato ITAG map");
    $self->set_long_name("Tomato (Solanum lycopersicum) ITAG map");
    $self->set_units("MB");

    print STDERR "Caching chromosome lengths...\n";
    my @ITAG_releases = CXGN::ITAG::Release->find();

    # if we can't find any ITAG releases, just return
    # otherwise the comparative viewer may crash...
    #
    if (! @ITAG_releases) { return $self; }
	
    $self->set_release_gff($ITAG_releases[0]->get_file_info('contig_gff3')->{file});
    print STDERR  "Working with the file ".($self->get_release_gff())."\n";

    # we need to cache the chromosome length information on the filesystem...
    $self->cache_chromosome_lengths();
    return $self;
}

our $SCALE=1000000;
our $INTER_CONTIG_DISTANCE=100_000;


sub get_chromosome { 
    my $self   = shift;
    my $chr_nr = shift;

    my $file = $self->get_release_gff();

    my $itag = CXGN::Cview::Chromosome::ITAG->new($chr_nr, 100, 10, 10, $self->get_release_gff(), $self->get_dbh());

    $itag->rasterize(0);
    $itag->set_rasterize_link("");
    foreach my $c ($itag->get_markers()) { 
	$c->set_show_tick(1);
	$c->show_label(1);

    }
  
    $itag->set_name();
    $itag->set_caption("");
    $itag->set_height(100);

#    $itag->distribute_labels();
    
    return $itag;
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

sub get_abstract { 
    my $self =shift;
    return "<p>The ITAG map shows the contig assembly and the corresponding BACs as used by the most recent annotation from the International Tomato Annotation Group (ITAG, see <a href=\"http://www.ab.wur.nl/TomatoWiki\">ITAG Wiki</a>). Clicking on the contigs will show the ITAG annotation in the genome browser.";

}


sub show_stats { 
    return 1;
}

sub set_files { 
    my $self=shift;
    $self->{files}=shift;
}

sub get_marker_type_stats { 
    my $self = shift;
    
}

sub get_map_stats { 
        return "Only contigs containing phase 3 BACs annotated by the ITAG consortium are shown on this map.";
}

sub get_marker_count { 
    my $self = shift;
    my $chr_nr = shift;
    
    open(my $ITAG, "<".$self->get_release_gff()) || die "Can't open the release file ".$self->get_release_gff();

    my $contig_count=0;
    my $bac_count = 0;
    my $old_contig = "";

    while (<$ITAG>) { 
	chomp;
	if (/^\#/) { next; }

	my $n;
	if (/^C(\d+)/) { 
	    $n = $1;
	}
	if ($n == $chr_nr) { 
	    my ($contig, $bac) = (split/\t/)[0, 8];
	    
	    if ($contig ne $old_contig) { 
		$contig_count++;
	    }
	    $bac_count++;    
	}
    }
    return $bac_count+$contig_count;
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
    my $self=shift;

    my $vh = CXGN::VHost->new();
    my $len_cache_path = $vh->get_conf("basepath")."/".$vh->get_conf("tempfiles_subdir")."/cview/itag_map_chr_len_cache.txt";
    
    my @lengths = ();
      if (! -e $len_cache_path) { 
  	open (my $LENCACHE, ">$len_cache_path") || die "Can't open the len cache $len_cache_path\n";

	foreach my $chr_nr (1..12) { 

	    my $c = CXGN::Cview::Chromosome::ITAG->new($chr_nr, 100, 10, 10, $self->get_release_gff(), $self->get_dbh());
	    
	    print $LENCACHE $chr_nr."\t".$c->get_length()."\n";
	    push @lengths, $c->get_length();
	    print STDERR "Caching chromosome length for chromosome $chr_nr, ".($c->get_length())."\n";
	}

 	while (<$LENCACHE>) { 
 	    chomp;
 	    my ($chr_nr, $len) = split /\t/;
 	    push @lengths, $len;
 	}
	
  	$self->set_chromosome_lengths(@lengths);
  	close($LENCACHE);
      } else {
	open (my $LENCACHE, "<$len_cache_path") || die "Can't open the agp chr len cache file $len_cache_path\n";
	while(<$LENCACHE>) { 
	    chomp;
	    my ($chr_nr, $len) = split /\t/;
	    push @lengths, $len;
	    
	}
	close($LENCACHE);
	$self->set_chromosome_lengths(@lengths);
    }

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

=head2 accessors get_release, set_release

 Usage:
 Desc:
 Property
 Side Effects:
 Example:

=cut

sub get_release_gff {
  my $self = shift;
  return $self->{release_gff}; 
}

sub set_release_gff {
  my $self = shift;
  my $file = shift;
  if (!$file) { die "no release file available."; }
  $self->{release_gff} = $file;
}
    



return 1;
