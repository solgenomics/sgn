
use Modern::Perl;

package SGN::Controller::Cview;

use Moose;
use namespace::autoclean;

BEGIN { extends "Catalyst::Controller" } 
with 'Catalyst::Component::ApplicationAttribute';

use Cache::File;
use File::Spec;
use HTML::Entities;
use URI::Escape;

use CXGN::Cview::MapFactory;
use CXGN::Cview::Map::Tools;
use CXGN::Cview::MapOverviews::Generic;
use CXGN::Phenome::Population;
use CXGN::People::Person;
use CXGN::Map;

has 'cview_default_map_id' => ( 
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

sub auto :Args(0) { 
    my ($self, $c) = @_;
    
    # push some useful stuff on the stash
    #
    $c->stash->{dbh} = $c->dbc->dbh();
    
    $c->stash->{map_url} = '/cview/map.pl';
    $c->stash->{chr_url} = '/cview/view_chromosome.pl';
    $c->stash->{marker_search_url} = '/search/markers/markersearch.pl';
    $c->stash->{comp_maps_url} = '/cview/view_maps.pl';
    $c->stash->{default_map_id} = $self->cview_default_map_id;
    $c->stash->{referer} = $c->req->referer();
    $c->stash->{tempdir} = $c->get_conf("tempfiles_subdir")."/cview";
    $c->stash->{basepath} = $c->get_conf("basepath");
    $c->stash->{cview_db_backend} = $c->get_conf("cview_db_backend");

    $c->log->debug("BASEPATH: ".($c->stash->{basepath})) if $c->debug;

    return 1;
}

# for backwards compatibility
sub alt_index :Path("/cview/index.pl") :Args(0) { 
    my ($self, $c) = @_;
    $c->forward("index");
}

sub index :Path("/cview") :Args(0) { 
    my ($self, $c) = @_;
    
    $c->stash->{template} = '/cview/index.mas';

    my $map_factory = CXGN::Cview::MapFactory->new($c->dbc->dbh, $c->config);
    my @maps = $map_factory->get_system_maps();
    
    my %map_by_species;

    foreach my $map (@maps) {	
	my $species = $map->get_common_name();
	my $short_name = $map->get_short_name();
	my $long_name = $map->get_long_name() || $short_name;       
	my $id = $map->get_id();
	
	my $map_is_private = $self->data_is_private($c, $c->dbc->dbh(), $map);
	
	unless ($map_is_private) {
	    push @{$map_by_species{$species} },
	    qq{<a href="}.$c->stash->{map_url}.qq{?map_version_id=$id">}.encode_entities($short_name).'</a>: '.encode_entities($long_name)."\n";
	}
    }

    $c->stash->{map_by_species} = \%map_by_species;    
    $c->forward("View::Mason");
}

sub map :Path("/cview/map.pl") :Args(0) { 
    my ($self, $c) = @_;
    
    my @params = qw | map_id map_version_id size hilite physical force map_items |;

    foreach my $param (@params) { 
	$c->stash->{$param} = $c->req->param($param) || '';
    }

    my %marker_info;

    # set up a cache for the map statistics, using Cache::File
    #
    my $cache_file_dir = File::Spec->catfile($c->stash->{basepath}, 
					     $c->stash->{tempdir}, "cache_file");

    tie %marker_info, 'Cache::File', { cache_root => $cache_file_dir };

    # report some unusual conditions to the user.
    #
    my $message = ""; 

    # if the map_id was supplied, convert immediately to map_version_id
    #
    if ($c->stash->{map_id} && !$c->stash->{map_version_id}) { 
	$c->stash->{map_version_id} = CXGN::Cview::Map::Tools::find_current_version($c->stash->{dbh}, $c->stash->{map_id});
    }
    # get the map data using the CXGN::Map API.
    #
    my $map_factory = CXGN::Cview::MapFactory->new($c->stash->{dbh});
    my $map = $map_factory ->create({ map_version_id => $c->stash->{map_version_id} });

    if (!$map) {
	$c->stash->{template} = '/cview/map/missing.mas';
	$c->stash->{title} = "The map you are trying to view does not exist!";
	return;
    }

    my $private = $self->data_is_private($c, $c->stash->{dbh}, $map);

    $c->stash->{long_name} = $map->get_long_name();
    $c->stash->{short_name} = $map->get_short_name();


    my @hilite_markers = split /\s+|\,\s*/, $c->{stash}->{hilite};

    $c->stash->{hilite_markers} = \@hilite_markers;

    # calculate the size of the image based on the size parameter
    #
    my $image_height = 160;
    my $size = $c->stash->{size} || 0;

    if ($size < 0 ) { $size = 0;  }
    if ($size > 10) { $size = 10; }

    $c->stash->{size} = $size || 0;

    $image_height = $image_height + $image_height * $size /2;
    my $image_width = 820;

    # create an appropriate overview diagram - physical or generic
    # (the generic will also provide an appropriate overview for the fish map).
    #
    my $map_overview = CXGN::Cview::MapOverviews::Generic ->
      new($map,
	  {
	   force            => $c->stash->{force},
	   basepath         => $c->stash->{basepath},
	   tempfiles_subdir => $c->stash->{tempdir},
	   dbh              => $c->stash->{dbh},
	  });

    $map_overview->set_image_height($image_height);
    $map_overview->set_image_width($image_width);

    # deal with marker names to be highlighted on the overview diagram
    # (the ones to be requested to be hilited using the hilite feature)
    #
    my @map_items = split /\n/, $c->stash->{map_items};

    $map_overview->get_map()->set_map_items(@map_items);
    foreach my $hm (@hilite_markers) {
      $map_overview -> hilite_marker($hm);
    }

    # generate the marker list for use in the URL links
    #
    my $hilite_encoded = URI::Escape::uri_escape(join (" ", @hilite_markers)); 

    # render the map and get the imagemap
    #
    $map_overview -> render_map();

    $c->stash->{overview_image} = $map_overview->get_image_html();

    # get the markers that could not be hilited
    #
    my @markers_not_found = $map_overview -> get_markers_not_found();

    if (@markers_not_found) {
      $message .= "The following markers requested for hiliting were not found on this map (click to search on other maps):<br />";
      foreach my $m (@markers_not_found) {
	$message .= "&nbsp;&nbsp;<a href=\"/search/markers/markersearch.pl?searchtype=exactly&amp;name=$m\">$m</a>";
      }
      $message .= "<br />\n";
    }

    # get chromosome stats and cache them
    #
    my @chr_names = $map->get_chromosome_names();
    my $hash_key = '';

    for (my $i=0; $i<@chr_names; $i++) {
	$hash_key = $c->stash->{map_version_id}."-".$i;
	if (!exists($marker_info{$hash_key}) || $c->stash->{force}) { 
	    $marker_info{$hash_key} = $map->get_marker_count($chr_names[$i]);
	}
    }
    
    if (!exists($marker_info{$c->stash->{map_version_id}}) || $c->stash->{force}) { 
	$marker_info{$c->stash->{map_version_id}} = $map->get_map_stats();
    }
    my $chr_info = '';

    my @chr_stats = ();
    for (my $i=0; $i<@chr_names; $i++) { 
	my $chr_link .= "<a href=\"".$c->stash->{chr_url}."?map_version_id=".$c->stash->{map_version_id}."&amp;chr_nr=$chr_names[$i]&amp;hilite=".$hilite_encoded."\">
<b>Chromosome $chr_names[$i]</b></a>";
	my $marker_link = join '',
           qq|<a href="/search/markers/markersearch.pl?w822_nametype=starts+with&w822_marker_name=&w822_mapped=on&w822_species=Any&w822_protos=Any&w822_colls=Any&w822_pos_start=&w822_pos_end=&w822_confs=Any&w822_submit=Search&w822_chromos=$chr_names[$i]&w822_maps=| . $c->stash->{map_id} . '">' . $marker_info{$c->stash->{map_version_id} . '-' . $i} . "</a>\n";

	push @chr_stats, [ $chr_link, $marker_link, $marker_info{$c->stash->{map_version_id}."-".$i} ];
    }
    
##    my @chromosome_stats = map { $marker_info{$c->stash->{map_version_id}."-".$_}}  $map->get_chromosome_names();
    
    $c->stash->{message} = $message;
    $c->stash->{abstract} = $map->get_abstract();
    $c->stash->{can_overlay} = $map->can_overlay();
    
    $c->stash->{marker_stats} = $marker_info{$c->stash->{map_version_id}};

    $c->stash->{chromosome_stats} = \@chr_stats;

    $c->stash->{parent1_stock_id} = $map->get_parent1_stock_id();
    $c->stash->{parent1_stock_name} = $map->get_parent1_stock_name();
    $c->stash->{parent2_stock_id} = $map->get_parent2_stock_id();
    $c->stash->{parent2_stock_name} = $map->get_parent2_stock_name();

    $c->stash->{template} = "/cview/map/index.mas";
    $c->forward("View::Mason");
}


sub data_is_private {
    my $self = shift;
    my $c = shift;
    my $dbh = shift;
    my $map = shift;
  
    my $pop_name = $map->get_short_name() || $map->get_long_name();
    
    my ($is_public, $owner_id);
    my $pop_id;
    if ($pop_name) {
	my $pop = CXGN::Phenome::Population->new_with_name($dbh, $pop_name);
	if ($pop) {
	    $pop_id = $pop->get_population_id();
	    $is_public = $pop->get_privacy_status();
	    $owner_id  = $pop->get_sp_person_id();
	}
   }
    
    my ($login_id, $user_type);
    if ($c->user()) { 
	#my ($login_id, $user_type) = CXGN::Login->new($dbh)->has_session();
	$user_type = $c->user()->get_object->get_user_type();
	$login_id = $c->user()->get_object->get_sp_person_id();
    }
	
    if ($is_public ||
	$user_type && $user_type eq 'curator' ||
        $login_id  && $owner_id && $login_id == $owner_id )  {
	return undef;
    } 
    else {
	if ($pop_id) {     
	
	   my $submitter = CXGN::People::Person->new($dbh, $owner_id);
           no warnings 'uninitialized';
    	   my $submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();
    	   my $submitter_link = qq |<a href="/solpeople/personal-info.pl?sp_person_id=$owner_id">$submitter_name</a> |;
       
	   my $private = qq | <p>This genetic map is not public yet. 
       	              If you would like to know more about this data, 
                      please contact the owner of the data: <b>$submitter_link</b> 
                      or email to SGN:
                      <a href=mailto:sgn-feedback\@sgn.cornell.edu>
                      sgn-feedback\@sgn.cornell.edu</a>.
                    </p> |;

         return $private;
 } else {
return undef; }
    } 
    
}


sub chromosome :Path("/cview/view_chromosome.pl") :Args(0) { 
    my ($self, $c) = @_;

    my @params = qw | map_id map_version_id chr_nr cM zoom show_physical show_ruler show_IL comp_map_id comp_map_version_id comp_chr color_model map_chr_select size hilite cM_start cM_end confidence show_zoomed marker_type show_offsets force clicked |;
    
    foreach my $param (@params) { 
	$c->stash->{$param}= $c->req->param($param);
    }

    $c->stash->{template} = '/cview/chr/index.mas';
    $c->forward("View::Mason");
}


sub maps :Path("/cview/view_maps.pl") :Args(0) { 
    my ($self, $c) = @_;

    $c->stash->{template} = '/cview/map/comparison.mas';
    $c->stash->{dbh} = $c->dbc->dbh();

    my @params = qw | center_map center_map_version_id show_physical show_ruler show_IL left_map left_map_version_id right_map right_map_version_id color_model |; 
    foreach my $param (@params) { 
	$c->stash->{$param} = $c->req->param($param);
    }
    $c->forward("View::Mason");
}

sub map_submission :Path('/cview/help/map_submission') :Args(0) { 
    my ($self, $c) = @_;
    $c->stash->{template}='/cview/help/map_submission.mas';
}



1;
