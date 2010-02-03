


=head1 NAME
           
CXGN::Cview::Map::SGN::Physical - a class to display physical maps in the SGN comparative viewer
                    
=head1 DESCRIPTION

This class queries the SGN database (particularly the physical schema) for information about BAC associations with the genetic map.

The class inherits from CXGN::Cview::Map and overrides 4 functions: new(), get_chromosome(), get_overview_chromosome(), get_chromosome_connections(). 

=head1 AUTHOR(S)

Lukas Mueller <lam87@cornell.edu>

=head1 FUNCTIONS

This class implements the following functions:

=cut

use strict;

package CXGN::Cview::Map::SGN::Physical;

use CXGN::Cview::Map::SGN::Genetic;
use CXGN::Cview::Chromosome::Physical;
use CXGN::Cview::Marker::Physical;
use CXGN::Cview::Legend::Physical;

use base qw | CXGN::Cview::Map::SGN::Genetic |;

=head2 function new()

overridden to set some physical-specific properties.

=cut

sub new {
    my $class = shift;
    my $dbh = shift;
    my $id = shift;

    my $db_id = &get_db_id($dbh, $id);
    my $self = $class -> SUPER::new($dbh, $db_id);

    if (!defined($self)) { return undef; }
    $self->set_preferred_chromosome_width(18);
    $self->set_short_name("Tomato Physical map");
    $self->set_long_name("Solanum lycopersicum Physical Map");
    
    $self->set_id($id);

    $self->set_legend(CXGN::Cview::Legend::Physical->new()); # set to empty legend for now.

    return $self;
}

=head2 function get_chromosome()

overridden to get a physical chromosome.

=cut

sub get_chromosome {
    my $self = shift;
    my $chr_nr = shift;

    my $map_factory = CXGN::Cview::MapFactory->new($self->get_dbh());
    my $id = get_db_id($self->get_dbh(), $self->get_id());
    #print STDERR "[Physical] get_chromosome $id.\n";
    my $genetic_map = $map_factory->create({map_version_id=>$id});
    my $genetic=$genetic_map->get_chromosome($chr_nr);
    my $physical = CXGN::Cview::Chromosome::Physical->new();

    my $largest_offset = 0;

    foreach my $m ($genetic->get_markers()) { 
	$m->set_chromosome($physical);
	$physical->add_marker($m);
	my $offset = $m->get_offset();
	if ($offset > $largest_offset) { 
	    $largest_offset=$offset;
	}
	$m->hide();
    }
	
    my $query = "SELECT distinct(bac_id), marker_id, alias, lg_name, position,  cornell_clone_name, contig_name, association_type, status
                   FROM physical.bac_marker_matches LEFT JOIN sgn_people.bac_status using (bac_id) WHERE lg_name=?  GROUP BY bac_id, marker_id, alias, lg_name, position, cornell_clone_name, contig_name, association_type, status ORDER BY status, position, association_type ";
    
     my $sth = $self->get_dbh()->prepare($query);

    $sth -> execute($chr_nr);
    while (my ($bac_id, $marker_id, $alias, $lg_name, $offset, $bac_name, $contig_name, $type, $status ) = $sth->fetchrow_array()) {
	#print STDERR "Physical: Marker Read: $bac_id\t$marker_id\t$offset\t$bac_name\t$type\t$status\n";
	my $bac = CXGN::Cview::Marker::Physical->new($physical, $marker_id);
	$bac->set_offset($offset);
	#$bac->set_($bac_id);

	my $url = $self->get_marker_link($bac_id);
	$bac->set_name($bac_name);
	


	my $clone = CXGN::Genomic::Clone->retrieve($bac_id);
	my $clone_name = $clone->clone_name_with_chromosome() || $clone->clone_name();
	$bac->set_marker_name($clone_name);
	$bac->get_label()->set_name($clone_name);
	$bac->get_label()->set_url($url);

	$bac->set_url($url);

	# highlite pennellii BACs differently.
	if ($clone_name =~ /Lpen/i) { 
	    $type = "Lpen_manual";
	    #print STDERR "Adding a pennellii BAC [$clone_name] to the map on chr $chr_nr...\n";
	}
	$bac->set_color( CXGN::Cview::Map::Tools::get_physical_marker_color($type, $status) );

	if (!$status) { $status="none"; }
	$bac->set_tooltip("$clone_name. Status: $status. Anchoring: $type. Marker: $alias.");
	$physical -> add_marker($bac);
	if ($offset>$largest_offset) { $largest_offset = $offset; }
	
    }   
    $physical->set_length($largest_offset);

    return $physical;
   
}

=head2 function get_overview_chromosome()

this is overridden because the overview chromosome on the physical is very different from the detail view.

=cut

sub get_overview_chromosome {
    my $self = shift;
    my $chr_nr = shift;
    
    my $physical = CXGN::Cview::Chromosome::BarGraph->new();

    my $largest_offset = 0;
    my $query = 
    "
        SELECT 
            distinct(physical.bacs.bac_id), 
            marker_experiment.marker_id, 
            position 
        FROM 
            map_version
            inner join linkage_group using (map_version_id)
            inner join marker_location using (lg_id)
            inner join marker_experiment using (location_id)
            inner join physical.probe_markers using (marker_id)
            inner join physical.overgo_associations using (overgo_probe_id)
            inner join physical.bacs using (bac_id) 
            inner join physical.oa_plausibility using (overgo_assoc_id) 
        where 
            map_version.map_version_id=? 
            and lg_name=? 
            and current_version='t' 
            and physical.oa_plausibility.plausible=1
    ";

#    print STDERR "Query: $query\n";
    my $sth = $self->get_dbh()->prepare($query);
    $sth -> execute(get_db_id($self->get_dbh(), $self->get_id()), $chr_nr);
    while (my ($bac_id, $marker_id, $offset) = $sth->fetchrow_array()) {
	#print STDERR "Physical: Marker Read: $bac_id\t$marker_id\t$offset\n";
	$physical -> add_association("overgo", $offset, 1);
	if ($offset>$largest_offset) { $largest_offset = $offset; }
	
    }   
    my $sgn = $self->get_dbh() -> qualify_schema("sgn");
    my $computational_query = "
         SELECT distinct(physical.computational_associations.clone_id), 
                physical.computational_associations.marker_id,
                marker_location.position
           FROM physical.computational_associations
           JOIN $sgn.marker_experiment using(marker_id)
           JOIN $sgn.marker_location using (location_id) 
           JOIN $sgn.linkage_group using (lg_id)
           JOIN $sgn.map_version on (map_version.map_version_id=linkage_group.map_version_id) 
          WHERE map_version.map_version_id=?
                AND linkage_group.lg_name=?
          ORDER BY marker_location.position
          ";
    
    my $cq_sth = $self->get_dbh()->prepare($computational_query);

    $cq_sth->execute(get_db_id($self->get_dbh(), $self->get_id()), $chr_nr);
    
    while (my ($clone_id, $marker_id, $offset)=$cq_sth->fetchrow_array()) { 
	$physical -> add_association("computational", $offset, 1);
    }
    $physical->set_length($largest_offset);
    $physical->set_width(30);
    my $id = $self->get_id();
    $physical->set_url("/cview/view_chromosome.pl?map_version_id=$id&chr_nr=$chr_nr");
    return $physical;    


}



=head2 function get_chromosome_connections()

overridden to get the appropriate connections for the physical map. Currently, it returns an empty list, because it has no connections.

=cut

sub get_chromosome_connections {
    my $self = shift;
    my $chr_nr = shift;
    my @list = ();
    # this map has no connections.!!!!
#    push @list, { map_version_id=>CXGN::Cview::Map::Tools::find_current_version($self->get_dbh(), CXGN::Cview::Map::Tools::current_tomato_map_id), lg_name=>$chr_nr, marker_count=>"?", short_name=>"F2-2000" };
    return @list;
}

sub get_db_id { 
    my $dbh = shift;
    my $id = shift;
    my $db_id = $id;
    $db_id=~s/.*(\d+)/$1/;
    return CXGN::Cview::Map::Tools::find_current_version($dbh, $db_id);
}


sub can_zoom { 
    return 0;
}

sub get_abstract { 
    
    return <<ABSTRACT;

    <p>This map shows the positions of the anchored BACs relative to the <a href="/cview/map.pl?map_id=9">Tomato EXPEN2000</a> map.</p>
	
	<p>The BACs were anchored using a number of  methods:
<dl>
<dt>overgo technology</dt>
<dd>overgos were designed from the markers and assayed in a multiplex strategy. More information on the <a href="/maps/physical/overgo_process_explained.pl">overgo process is available</a>. These are shown in light green on the overview.
<dt>computational</dt>
<dd>Marker sequences on the F2-2000 were computationally matched to BAC end sequences. Matching BACs were associated to the map as anchor BACs. These are shown in light red on the overview.</dd>
<dt>manual</dt>
<dd>Additional experiments were performed on a case by case basis, or information for the association of a BAC was available from the literature.</dd>
</dl>


ABSTRACT

}

sub get_marker_link { 
    my $self = shift;
    my $clone_id= shift; 
    if ($clone_id) { return "/maps/physical/clone_info.pl?id=$clone_id"; }
    else { return ""; }
}

sub get_marker_count { 
    my $self = shift;
    my $chr_nr = shift;

    my $query = "SELECT count(distinct(bac_id)) from physical.bac_marker_matches WHERE lg_name=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($chr_nr);
    my ($count) = $sth->fetchrow_array();

    return $count; 
}

sub get_map_stats { 
    my $self = shift;

    my $query = "SELECT count(distinct(bac_id)) from physical.bac_marker_matches";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute();
    my ($count) = $sth->fetchrow_array();

    return "$count BACs have been assigned to this map";


}


return 1;
