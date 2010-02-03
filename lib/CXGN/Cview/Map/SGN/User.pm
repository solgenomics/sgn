
=head1 NAME
           
CXGN::Cview::Map::SGN::User - a class acting as an adaptor to user submitted maps.
           
=head1 SYNOPSYS

         
=head1 DESCRIPTION

This class delegates most of the functionality to the CXGN::Person::UserMap* classes, which are also needed for the interactive data editing pages (based on CXGN::Page::Form::SimpleFormPage).

=head1 AUTHOR(S)

Lukas Mueller <lam87@cornell.edu>

=head1 VERSION
 

=head1 LICENSE


=head1 FUNCTIONS


This class implements the following functions:

=cut

use strict;

package CXGN::Cview::Map::SGN::User;

use CXGN::Cview::Map;
use CXGN::People::UserMap;
use CXGN::Login;


use base qw | CXGN::Cview::Map |;

=head2 function new()

  Synopsis:	constructor
  Example:      my $map = CXGN::Cview::Map::SGN::User->new($dbh, "u234");
  Arguments:	a database handle
                a user map id, including the leading "u".
  Returns:	a CXGN::Cview::Map::SGN::User object, if the 
                corresponding object is defined, an empty object
                otherwise
  Side effects:	queries the database for the object
  Description:	

=cut

sub new {
    my $class = shift;
    my $dbh = shift;
    my $id = shift;
    my $self = $class->SUPER::new($dbh);

    $self->set_id($id);
    if ($self->get_id()) { 
	$self->fetch();
	if (!$self->get_chromosome_count()) { 
	    return undef;  # the map id did not have a legal map
	}
    }
	
    my $login = CXGN::Login->new($self->get_dbh());

    if (!$self->get_is_public() && ($login->has_session() != $self->get_sp_person_id())) { 
	return undef;
    }
    return $self;
}

=head2 function fetch()

  Synopsis:	
  Arguments:	none
  Returns:	nothing
  Side effects:	populates the object from the database
  Description:	

=cut

sub fetch {
    my $self = shift;

    # getting the chromosome names..

    my $chr_q = "SELECT distinct(linkage_group) FROM sgn_people.user_map_data WHERE 
                 user_map_id=? AND obsolete='f'";

    my $chr_h = $self->get_dbh()->prepare($chr_q);
    $chr_h->execute($self->get_db_id($self->get_id()));
    my @chr_names = ();
    while (my ($name) = $chr_h->fetchrow_array()) { 
	push @chr_names, $name;
    }
    #print STDERR "CHROMOSOMES on map ".($self->get_db_id($self->get_id()))." : ".(join "|", @chr_names)."\n";
    $self->set_chromosome_names(@chr_names);
    $self->set_chromosome_count(scalar(@chr_names)); 
    
    # getting the chromosome lengths...
    my $len_q = "SELECT linkage_group, max(position) FROM sgn_people.user_map_data WHERE user_map_id=? and obsolete='f' GROUP BY linkage_group ";
    my $len_h = $self->get_dbh()->prepare($len_q);
    $len_h->execute($self->get_db_id($self->get_id())); 
    my @lengths = ();
    while (my ($chr, $length) = $len_h->fetchrow_array()) { 
	push @lengths, $length;
    }
    $self->set_chromosome_lengths(@lengths);

    my $map = CXGN::People::UserMap->new($self->get_dbh(), $self->get_id);
    $self->set_map($map);

    $self->set_short_name($self->get_map()->get_short_name());
    $self->set_long_name($self->get_map()->get_short_name());
    
	
}



=head2 accessors set_id(), get_id()

  Property:	the id of the map, usually a "u" followed 
                by a number, which corresponds to a database
                identifier
  Side Effects:	
  Description:	

=cut

sub get_id { 
    my $self=shift;
    return $self->{id};
}

sub set_id { 
    my $self=shift;
    $self->{id}=shift;
}


=head2 get_chromosome()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_chromosome {
    my $self = shift;
    my $chr_nr = shift;
    my $chromosome = CXGN::Cview::Chromosome->new();
    $chromosome->set_caption($chr_nr);
    my $query = "SELECT marker_name, position, protocol, confidence FROM sgn_people.user_map_data WHERE user_map_id = ? and linkage_group = ? and obsolete='f' ORDER BY position";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($self->get_db_id($self->get_id), $chr_nr);
    while (my ($marker_name, $position, $protocol, $confidence) = $sth->fetchrow_array()) { 
	my $marker = CXGN::Cview::Marker->new($chromosome);
	$marker->set_name($marker_name);
	$marker->set_offset($position);
	$marker->set_marker_type($protocol);
	$marker->set_confidence($confidence);
	$marker->set_marker_name($marker_name);
	$marker->get_label()->set_name($marker_name);
	$marker->hide();
	$chromosome->add_marker($marker);
    }
#    print STDERR "******* Generating user chromosome $chr_nr...\n";
    $chromosome->_calculate_chromosome_length();
    $chromosome->set_width(16);
    return $chromosome;
}

sub get_overview_chromosome { 
    my $self = shift;
    my $chr_nr = shift;
    
    my $chromosome = $self->get_chromosome($chr_nr);
    
    foreach my $m ($chromosome->get_markers()) { 
	$m->hide();
    }
    $chromosome->set_width(12);
    return $chromosome;
}

sub get_chromosome_section { 
    my $self = shift;
    my $chr_nr = shift;
    my $start = shift;
    my $end = shift;
    my $chromosome = $self->get_chromosome($chr_nr);
    $chromosome->set_caption("");
    $chromosome->set_section($start, $end);
    $chromosome->set_length($end-$start);
    $chromosome->_calculate_chromosome_length();
    $chromosome->set_width(16);
    foreach my $m ($chromosome->get_markers()) { 
	$m->unhide();
	$m->get_offset_label()->set_name($m->get_offset());
    }

    return $chromosome;
}



=head2 function assign_markers()

  Synopsis:	$user_map->assign_markers()
  Arguments:	none
  Returns:	nothing
  Side effects:	attempts to find each marker name in the sgn 
                marker_alias table and assigns the marker_id of 
                the marker found. If no marker is found, the id is NULL.
                If more than one marker are found, the marker_id of the 
                first marker returned is chosen at random.
  Description:	NOT YET IMPLEMENTED

=cut

sub assign_markers {
}

sub can_zoom { 
    return 1;
}

sub initial_zoom_height { 
    return 5;
}

=head2 get_marker_count()

 Usage:        see L<CXGN::Cview::Map>
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_marker_count {
    my $self = shift;
    my $chr_name = shift;
    my $query = "SELECT count(user_map_data_id) FROM sgn_people.user_map_data WHERE linkage_group=? AND user_map_id=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($chr_name, $self->get_db_id($self->get_id()));
    my ($marker_count) = $sth->fetchrow_array();
    return $marker_count;
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
    my $lg_name = shift;

    # check the system maps first...
    #
        my $query = 
	
       #"  SELECT 
#             c_map_version.map_version_id,
#             c_map.short_name, 
#             c_linkage_group.lg_name, 
#             count(distinct(marker.marker_id)) as marker_count 
#         from 
#             marker
#             join marker_experiment using(marker_id)
#             join marker_location using (location_id)
#             join linkage_group on (marker_location.lg_id=linkage_group.lg_id)
#             join map_version on (linkage_group.map_version_id=map_version.map_version_id)

#             join marker_experiment as c_marker_experiment on
#                  (marker.marker_id=c_marker_experiment.marker_id)
#             join marker_location as c_marker_location on 
#                  (c_marker_experiment.location_id=c_marker_location.location_id)
#             join linkage_group as c_linkage_group on (c_marker_location.lg_id=c_linkage_group.lg_id)
#             join map_version as c_map_version on 
#                  (c_linkage_group.map_version_id=c_map_version.map_version_id)
#             join map as c_map on (c_map.map_id=c_map_version.map_id)
#         where 
#             map_version.map_version_id=? 
#             and linkage_group.lg_name=? 
#             and c_map_version.map_version_id !=map_version.map_version_id 
#             and c_map_version.current_version='t'
#         group by 
#             c_map_version.map_version_id,
#             c_linkage_group.lg_name,
#             c_map.short_name
#         order by 
#             marker_count desc"

       "SELECT map_version.map_version_id, short_name,
              linkage_group.lg_name, count(distinct(marker_experiment.marker_id)) as marker_count
         FROM sgn_people.user_map_data JOIN sgn.marker_experiment using(marker_id)
         JOIN sgn.marker_location using (location_id) 
         JOIN sgn.map_version USING (map_version_id)
         JOIN sgn.map USING (map_id)
         JOIN sgn.linkage_group ON (marker_location.lg_id=linkage_group.lg_id)
        WHERE sgn_people.user_map_data.user_map_id=? and user_map_data.linkage_group=?
        GROUP BY map_version.map_version_id,
                 linkage_group.lg_name,
                 map.short_name
        ORDER BY marker_count desc";
    
    my $sth = $self->get_dbh() -> prepare($query);
    $sth -> execute($self->get_db_id($self->get_id()), $lg_name);
    my @chr_list = ();

    #print STDERR "***************** Done with query..\n";
    while (my $hashref = $sth->fetchrow_hashref()) {
	#print STDERR "READING----> $hashref->{map_version_id} $hashref->{lg_name} $hashref->{marker_count}\n";
	push @chr_list, $hashref;

    }

    # then check other user maps, depending on their is_public status
    # and who is logged in.
    #
    my $user_map_q = "SELECT 'u'||cmap.user_map_id, cmap.short_name, cmap_data.linkage_group, count(distinct(cmap_data.user_map_data_id)) as marker_count FROM sgn_people.user_map JOIN user_map_data using(user_map_id) JOIN user_map_data as cmap_data ON (user_map_data.marker_name=cmap_data.marker_name) JOIN user_map as cmap ON (cmap_data.user_map_id=cmap.user_map_id) WHERE user_map.user_map_id=? AND user_map_data.linkage_group=? AND (user_map.user_map_id != cmap.user_map_id) AND (cmap.is_public='t'  || cmap.sp_person_id=user_map.sp_person_id)
    GROUP by cmap.user_map_id, cmap_data.linkage_group, cmap.short_name
    ORDER BY marker_count desc";

    $sth = $self->get_dbh() -> prepare($user_map_q);
    $sth -> execute($self->get_db_id($self->get_id()), $lg_name);
    
    while (my $hashref = $sth->fetchrow_hashref()) { 
	push @chr_list, $hashref;
    }

   
    
    return @chr_list;


}





=head2 accessors get_is_public(), set_is_public()

if this map can be viewed by other users in addition to the submitter.

=cut

sub get_is_public {
    my $self=shift;
    return $self->get_map()->get_is_public();
    
}

sub set_is_public {
    my $self=shift;
    $self->get_map()->set_is_public(shift);
}

=head2 accessors get_sp_person_id(), set_sp_person_id()

 Usage:
 Desc:         thin wrapper around user map object
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_sp_person_id {
    my $self=shift;
    return $self->get_map()->get_sp_person_id();

}

sub set_sp_person_id {
    my $self=shift;
    $self->get_map()->set_sp_person_id(shift);
}


=head2 get_abstract()

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_abstract {
    my $self = shift;
    return $self->get_map()->get_abstract();
}




=head2 accessors get_map(), set_map()

 Usage:        
 Desc:         the User.pm class is a wrapper around the CXGN::People::UserMap
               class. This property stores corresponding the CXGN::People::UserMap
               object which many of the a
 Side Effects:
 Example:

=cut

sub get_map {
  my $self=shift;
  return $self->{map};

}

sub set_map {
  my $self=shift;
  $self->{map}=shift;
}




=head2 function get_db_id()

  Synopsis:	converts the id of the map to a database id.
                essentially, strips off characters from the 
                numbers...
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_db_id {
    my $self = shift;
    my $id = shift;
    if ($id =~ /u(\d+).*/) { 
	return $1;
    }
    return $id;
}

return 1;
