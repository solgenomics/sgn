
=head1 NAME

view_maps.pl

=head1 DESCRIPTION

A web script running under mod-perl that displays a comparison between 3 complete maps. The images are cached using L<CXGN::Tools::WebImageCache>.

Parameters:

=over 23

=item left_map

the map_id of the map to be displayed in the left track.

=item left_map_version_id

the map_version_id of the map to be displayed in the left track. left_map and left_map_version_id are mutually exclusive.

=item center_map

the map_id of the map to be displayed in the center track.

=item center_map_version_id

the map_version_id of the map to be displayed in the center track. Mutually excludes center_map.

=item right_map

the map_id to be displayed in the right track.

=item right_map_version_id

the map_version_id of the map to be displayed in the right track. right_map and right_map_version_id are mutually exclusive.

=back

Notes:

=over 3

=item

that the maps are always displayed filling the left and center slot before filling the right slot.

=item 

maps should be specified in links using the map_ids, as they are more stable (unless a specific map_version is desired). The map_id will be converted to the current map_version, which is used exclusively internally.

=head1 AUTHOR

Lukas Mueller (lam87@cornell.edu)

=head1 FUNCTIONS

This script contains a small class called CXGN::Cview::ViewMaps that has the following member functions:

=cut

use strict;

use CXGN::Page;


my $page = CXGN::Page->new();

my ($center_map, $center_map_version_id, $show_physical, $show_ruler, $show_IL, $left_map, $left_map_version_id, $right_map, $right_map_version_id, $color_model)
    = $page->get_arguments("center_map", "center_map_version_id", "show_physical", "show_ruler", "show_IL", "left_map", "left_map_version_id",  "right_map", "right_map_version_id", "color_model");

my $dbh = CXGN::DB::Connection->new();

if (!$left_map) { $left_map =0; }
if (!$center_map) { $center_map = 0; }
if (!$right_map) { $right_map = 0; }

# the map object accepts only either map id or map_version_id.
# let's have map_version_id trump map ids.
#
if ($left_map && $left_map_version_id) { 
    $left_map = 0;
}
if ($center_map && $center_map_version_id) { 
    $center_map =0;
}
if ($right_map && $right_map_version_id) { 
    $right_map = 0;
}

if (!$left_map_version_id) { 
    $left_map_version_id=CXGN::Cview::Map::Tools::find_current_version($dbh, $left_map); 
}

if (!$center_map_version_id) {
    $center_map_version_id=CXGN::Cview::Map::Tools::find_current_version($dbh, $center_map);
}

if (!$right_map_version_id) { 
    $right_map_version_id = CXGN::Cview::Map::Tools::find_current_version($dbh, $right_map);
}

my $map_factory = CXGN::Cview::MapFactory->new($dbh);

my @maps = ();
foreach my $id ($left_map_version_id, $center_map_version_id, $right_map_version_id) { 
    if ($id) { # skip maps that are not defined...
	#print STDERR "Generating map with map_version_id $id...";
       push @maps, $map_factory->create( { map_version_id=>$id });
	#print STDERR " Done.\n";
   }
} 

my $vm = CXGN::Cview::ViewMaps -> new($dbh);
$vm -> set_maps(@maps);
$vm -> generate_page();
$vm -> display();
$vm -> clean_up();

package CXGN::Cview::ViewMaps;

use CXGN::Page::FormattingHelpers qw | page_title_html |;
use CXGN::Cview::MapFactory;
use CXGN::Cview::Chromosome_viewer;
use CXGN::Cview::ChrLink;
use CXGN::Cview::Utils qw | set_marker_color |;
use CXGN::Cview::MapImage;
use CXGN::Tools::WebImageCache;
use CXGN::Map;
use CXGN::VHost;

use base qw( CXGN::DB::Object );

1;

=head2 function new()

  Synopsis:	
  Arguments:	none
  Returns:	a handle to a view_maps object
  Side effects:	
  Description:	constructor

=cut

sub new {
    my $class = shift;
    my $dbh = shift;
    my $page = CXGN::Page->new();
    my $self = bless {}, $class;
    $self->set_dbh($dbh);
    # set some defaults...
    #
    $self->{page} = $page;
    $self -> {unzoomedheight} = 20; # how many cM are seen at zoom level 1    

    return $self;
}

sub adjust_parameters {
    my $self = shift;
    
    # adjust input arguments
    #
    
    
}

=head2 accessors set_maps(), get_maps()

  Property:	
  Setter Args:	
  Getter Args:	
  Getter Ret:	
  Side Effects:	
  Description:	

=cut

sub get_maps { 
    my $self=shift;
    return @{$self->{maps}};
}

sub set_maps { 
    my $self=shift;
    @{$self->{maps}}=@_;
}

=head2 accessors set_cache(), get_cache()

  Property:	the CXGN::Tools::WebImageCache object
  Args/Ret:     the same
  Side Effects:	this is the object used to generate the 
                cache image.
  Description:	

=cut

sub get_cache { 
    my $self=shift;
    return $self->{cache};
}

sub set_cache { 
    my $self=shift;
    $self->{cache}=shift;
}




=head2 function generate_page()

  Arguments:	none
  Returns:	nothing
  Side effects:	generates the CXGN::Cview::MapImage and stores it
                to the cache if necessary, or reads just reads
                the image cache if it is still valid.

=cut

sub generate_page {
    my $self = shift;

    my $vhost = CXGN::VHost->new();
    my $cache = CXGN::Tools::WebImageCache->new();
    
    # define a key for the cache. lets just use the name of the
    # script and the map_version_ids of the maps being displayed
    #
    $cache->set_key("view_maps".(join "-", map { $_->get_id() } ($self->get_maps())));

    $cache->set_basedir($vhost->get_conf("basepath"));
    $cache->set_temp_dir(File::Spec->catfile($vhost->get_conf("tempfiles_subdir"), "cview"));
    $cache->set_expiration_time(86400);

    $self->set_cache($cache);

    if (! $self->get_cache()->is_valid()) { 
	my $map_width = $self->{map_width} = 720;    
	my $x_distance = $map_width/4; # the number of pixels the different elements are spaced
	my $row_count = 0;
	my $row_height = 120;    # the height of a row (vertical space for each chromosome image)
	my $y_distance = $row_height * (1/3);
	my $chr_height = $row_height * (2/3);
	my $map_height;
	
	# determine the maximum chromosome count among all maps
	# so that we can accommodate it
	#
	my $max_chr = 0;
	foreach my $m ($self->get_maps()) { 
	    my $chr_count = 0;
	    if ($m) { 
		$chr_count = $m->get_chromosome_count();
	    }
	    if ($chr_count > $max_chr) { $max_chr=$chr_count; }
	}
	
	$map_height = $row_height * $max_chr+2*$y_distance;
    	# show the ruler if requested
	#
#	if ($self->{show_ruler}) { 
#	    my $r = ruler->new($x_distance-20, $row_height * $row_count + $y_distance, $chr_height, 0, $self->{c}{$track}[$i]->get_chromosome_length());
#	    $self->{map}->add_ruler($r);
#	}
	$row_count++;
	
	$self->{map} = CXGN::Cview::MapImage -> new("", $map_width, $map_height);
	
	# get all the chromosomes and add them to the map
	#
	my $track = 0;
	foreach my $map ($self->get_maps()) { 
	    my @chr_names = $map->get_chromosome_names();
	    for (my $i=0; $i<$map->get_chromosome_count(); $i++) {	
		
		$self->{c}{$track}[$i] = ($self->get_maps())[$track]->get_chromosome($i+1);
		$self->{c}{$track}[$i] -> set_vertical_offset($row_height*$i+$y_distance);
		$self->{c}{$track}[$i] -> set_horizontal_offset($x_distance + $x_distance * ($track));
		$self->{c}{$track}[$i] -> set_height($chr_height);
		$self->{c}{$track}[$i] -> set_caption( $chr_names[$i] );
		$self->{c}{$track}[$i] -> set_width(16);
		$self->{c}{$track}[$i] -> set_url("/cview/view_chromosome.pl?map_version_id=".($self->get_maps())[$track]->get_id()."&amp;chr_nr=$i");
		
		$self->{c}{$track}[$i] -> set_labels_none();       
		$self->{map}->add_chromosome($self->{c}{$track}[$i]);
	    }
	    $track++;
	    
	}
	
	# get the connections between the chromosomes
	#
	my %find = ();
	
	for (my $track=0; $track<($self->get_maps()); $track++) { 
	    for (my $i =0; $i< ($self->get_maps())[$track]->get_chromosome_count(); $i++) { 
		foreach my $m ($self->{c}{$track}[$i]->get_markers()) { 
		    $m->hide_label();
		    # make entry into the find hash and store corrsponding chromosomes and offset 
		    # (for drawing connections)
		    # if the map is the reference map ($compare_to_map is false).
		    #
		    $find{$m->get_id()}->{$track}->{chr}=$i;
		    $find{$m->get_id()}->{$track}->{offset}=$m->get_offset();
		    
		    # set the marker colors
		    #
		    set_marker_color($m, "marker_types");
		}
		
	    }
	}
	foreach my $f (keys(%find)) { 
	    foreach my $t (keys %{$find{$f}}) { 
		my $chr = $find{$f}->{$t}->{chr};
		my $offset = $find{$f}->{$t}->{offset};
		
		if (exists($find{$f}->{$t-1}) || defined($find{$f}->{$t-1})) {
		    my $comp_chr = $find{$f}->{$t-1}->{chr};
		    my $comp_offset = $find{$f}->{$t-1}->{offset};
		    #print STDERR "Found on track $t: Chr=$chr offset=$offset, links to track ".($t-1)." Chr=$comp_chr offset $comp_offset\n";
		    if ($comp_chr) { 
			my $link1 = CXGN::Cview::ChrLink->new($self->{c}{$t}[$chr], $offset, $self->{c}{$t-1}[$comp_chr], $comp_offset);
			$self->{map}->add_chr_link($link1);
		    }
		}
		if (exists($find{$f}->{$t+1})) { 
		    my $comp_chr = $find{$f}->{$t+1}->{chr};
		    my $comp_offset = $find{$f}->{$t+1}->{offset};
		    my $link2 = CXGN::Cview::ChrLink->new($self->{c}{$t}[$chr], $offset, $self->{c}{$t+1}[$comp_chr], $comp_offset);
		    $self->{map}->add_chr_link($link2);		
		    
		}
	    }
	    
	}
	
	$self->get_cache()->set_map_name("viewmap");
	$self->get_cache()->set_image_data($self->{map}->render_png_string());
	$self->get_cache()->set_image_map_data($self->{map}->get_image_map("viewmap"));
	
# 	# show the ruler if requested
# 	#
# 	if ($self->{show_ruler}) { 
# 	    my $r = ruler->new($x_distance-20, $row_height * $row_count + $y_distance, $chr_height, 0, $self->{c}{$track}[$i]->get_chromosome_length());
# 	    $self->{map}->add_ruler($r);
# 	}
    }
    

	# my $filename = "cview".(rand())."_".$$.".png";
    
#     $self->{image_path} = $vhost_conf->get_conf('basepath').$vhost_conf->get_conf('tempfiles_subdir')."/cview/$filename";
#     $self->{image_url} = $vhost_conf->get_conf('tempfiles_subdir')."/cview/$filename";
    
#     $self->{map} -> render_png_file($self->{image_path});
    
#     $self->{imagemap} = $self->{map}->get_image_map("imagemap");

    
}

    
sub get_select_toolbar { 
    my $self = shift;
    
#    $left_map = $self->get_left_map() || 0;
#    $center_map = $self->get_center_map() || 0;
#    $right_map = $self->get_right_map || 0;
    my @names = ("left_map_version_id", "center_map_version_id", "right_map_version_id");
    my @selects = ();
    for (my $i=0; $i< 3; $i++) { 
	if ( defined(($self->get_maps())[$i])) { 
	    push @selects,  CXGN::Cview::Utils::get_maps_select($self->get_dbh(), ($self->get_maps())[$i]->get_id(), $names[$i], 1);
	}
	else { 
	    push @selects, CXGN::Cview::Utils::get_maps_select($self->get_dbh(), undef, $names[$i], 1);
	}
    }
#    my $center_select = CXGN::Cview::Utils::get_maps_select($self, !$center_map || $center_map->get_id(), "center_map_version_id", 1);
#    my $right_select = CXGN::Cview::Utils::get_maps_select($self, !$right_map || $right_map->get_id(), "right_map_version_id", 1);


    return qq { 
	<form action="#">
	    <center>
	    <table summary=""><tr><td>$selects[0]</td><td>$selects[1]</td><td>$selects[2]</td></tr></table>
	    <input type="submit" value="set" />
	    </center>
	</form>
	};
}

=head2 function display()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	composes the page and displays it.

=cut

sub display {
    my $self = shift;
    

    $self->{page}->header("SGN comparative mapviewer");
    my $width = int($self->{map_width}/3);
    
    my $select = $self->get_select_toolbar();
    
    print "$select";

    if (!$self->get_maps()) { 
	print "<br /><br /><center>Note: No maps are selected. Please select maps from the pull down menus above.</center>\n";
    }

    print $self->get_cache()->get_image_html();

#    print "<img src=\"$self->{image_url}\" usemap=\"#chr_comp_map\" border=\"0\" alt=\"\" />\n";

#    print $self->{map}->get_image_map("chr_comp_map");

    $self->{page}->footer();

    
    
}

=head2 function error_message_page()

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub error_message_page {
    my $self = shift;
    my $page = CXGN::Page->new();
    $page->header();

    my $title = page_title_html("Error: No center map defined");

    print <<HTML;
    
    $title
	<p>
	A center map needs to be defined for this page to work. Please supply
        a center_map_version_id as a parameter. If this was the result of a link,
	please inform SGN about the error.
	</p>
	<p>
	Contact SGN at <a href="mailto:sgn-feedback\@sgn.cornell.edu">sgn-feedback\@sgn.cornell.edu</a>

HTML

     $page->footer();

    exit();
}


sub clean_up {
    my $self = shift;
}

