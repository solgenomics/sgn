package CXGN::Cview::Map::SGN::Genetic;

=head1 NAME

CXGN::Cview::Map::SGN::Genetic - a class implementing a genetic map

=head1 DESCRIPTION

This class implements a genetic map populated from the SGN database. This class inherits from L<CXGN::Cview::Map>.

Note: the common name (available through get_common_name()) for the map organism is now taken through the following join: sgn.accession -> public.organism -> sgn.organismgroup_member ->sgn.organism_group (July 2010).

=head1 AUTHOR(S)

Lukas Mueller <lam87@cornell.edu>

=head1 FUNCTIONS

This class implements the following functions (for more information, see L<CXGN::Cview::Map>):

=cut

use strict;
use warnings;

use CXGN::Cview::Legend::Genetic;
use CXGN::Cview::Map;
use CXGN::Cview::Map::Tools;

use base qw | CXGN::Cview::Map |;

=head2 function new

  Synopsis:	my $genetic = CXGN::Cview::Map::SGN::Genetic->
                  new( $dbh, $map_version_id);
  Arguments:	(1) a database handle, preferably generated with
                    CXGN::DB::Connection
                (2) the map version id for the desired map.
  Returns:	a Genetic map object
  Side effects:	accesses the database
  Description:

=cut

sub new {
    my $class = shift;
    my $dbh = shift;
    my $map_version_id = shift;

    my $self = $class->SUPER::new($dbh);
    $self->set_id($map_version_id);
    $self->fetch();

    # set some defaults
    $self->set_preferred_chromosome_width(20);

    # fetch the chromosome lengths
    #
    my $query = "SELECT lg_name, max(position) FROM sgn.linkage_group JOIN sgn.marker_location USING(lg_id) WHERE linkage_group.map_version_id=? GROUP BY lg_name, lg_order ORDER BY lg_order";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($self->get_id());
    my @chromosome_lengths = ();
    while (my ($lg_name, $length) = $sth->fetchrow_array()) {
	push @chromosome_lengths, $length;
    }
    $self->set_chromosome_lengths(@chromosome_lengths);

    if ($self->get_chromosome_count() == 0) { return undef; }

    my $legend = CXGN::Cview::Legend::Genetic->new($self);
#    $legend->set_mode("marker_types");
    $self->set_legend($legend);

    return $self;
}

sub fetch {
    my $self = shift;

    # get the map metadata
    #
    my $query = "SELECT map_version_id, map_type, short_name, long_name, abstract, public.organism.common_name, organismgroup.name FROM sgn.map JOIN sgn.map_version using(map_id) LEFT JOIN sgn.accession on(parent_1=accession.accession_id) LEFT JOIN public.organism on (public.organism.organism_id=accession.chado_organism_id) LEFT JOIN sgn.organismgroup_member on (public.organism.organism_id=organismgroup_member.organism_id) join sgn.organismgroup using(organismgroup_id)  WHERE map_version_id=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($self->get_id());
    my ($map_version_id, $map_type, $short_name, $long_name, $abstract, $organism_name, $common_name) = $sth->fetchrow_array();
    $self->set_id($map_version_id);
    $self->set_type($map_type);
    $self->set_short_name($short_name);
    $self->set_long_name($long_name);
    $self->set_abstract($abstract);
    $self->set_organism($organism_name);
    $self->set_common_name($common_name);
    $self->set_units("cM");

    # get information about associated linkage_groups
    #
    my $chr_name_q = "SELECT distinct(linkage_group.lg_name), lg_order FROM sgn.linkage_group WHERE map_version_id=? ORDER BY lg_order";
    my $chr_name_h = $self->get_dbh()->prepare($chr_name_q);
    $chr_name_h->execute($self->get_id());
    my @names = ();
    while (my ($lg_name) = $chr_name_h->fetchrow_array()) {
	push @names, $lg_name;
    }
    $self->set_chromosome_names(@names);
    $self->set_chromosome_count(scalar(@names));
    $self->set_preferred_chromosome_width(20);

    # get the location of the centromeres
    #
    my $centromere_q = "SELECT lg_name, min(position) as north_centromere, max(position) as south_centromere FROM linkage_group left join marker_location on (north_location_id=location_id or south_location_id=location_id) where linkage_group.map_version_id=? group by linkage_group.lg_id, linkage_group.map_version_id, lg_order, lg_name order by lg_order";
    my $centromere_h = $self->get_dbh()->prepare($centromere_q);
    $centromere_h->execute($self->get_id());
    while (my ($lg_name, $north, $south) = $centromere_h->fetchrow_array()) {
	$self->set_centromere($lg_name, $north, $south);
    }


}

=head2 function get_chromosome
  Synopsis:	see L<CXGN::Cview::Map>
  Arguments:
  Returns:
  Side effects:
  Description:

=cut

sub get_chromosome {
    my $self = shift;
    my $chr_nr = shift;
#    my $marker_confidence_cutoff = shift; # the confidence cutoff. 3=frame 2=coseg 1=interval LOD=2 0=interval

#    if (!$marker_confidence_cutoff) { $marker_confidence_cutoff=-1; }

    my $chromosome = CXGN::Cview::Chromosome->new();
    $chromosome->set_name($chr_nr);
    $chromosome->set_caption($chr_nr);

    my %seq_bac = ();

    my $physical = 'physical';

    if ($self->get_id() == CXGN::Cview::Map::Tools::find_current_version($self->get_dbh(), CXGN::Cview::Map::Tools::current_tomato_map_id())) {

	# get the sequenced BACs
	#
	my $Sequenced_BAC_query =
        "
            SELECT
                distinct $physical.bac_marker_matches.bac_id,
                $physical.bac_marker_matches.cornell_clone_name,
                $physical.bac_marker_matches.marker_id,
                $physical.bac_marker_matches.position
            FROM
                $physical.bac_marker_matches
                LEFT JOIN sgn.linkage_group USING (lg_id)
                LEFT JOIN sgn_people.bac_status USING (bac_id)
            WHERE
                sgn.linkage_group.lg_name=?
                AND sgn_people.bac_status.status='complete'
        ";
	my $sth2 = $self->get_dbh->prepare($Sequenced_BAC_query);
	$sth2->execute($chr_nr);
	while (my ($bac_id, $name, $marker_id, $offset)=$sth2->fetchrow_array()) {
# print STDERR "Sequenced BAC for: $bac_id, $name, $marker_id, $offset...\n";
	    $name = CXGN::Genomic::Clone->retrieve($bac_id)->clone_name();

	    my $m = CXGN::Cview::Marker::SequencedBAC->new($chromosome, $bac_id, $name, "", "", "", "", $offset);
	    $m->get_label()->set_text_color(200,200,80);
	    $m->get_label()->set_line_color(200,200,80);
	    $seq_bac{$marker_id}=$m;
	}
    }

    # get the "normal" markers
    #
    my $query =     "
        SELECT
            marker_experiment.marker_id,
            alias,
            mc_name,
            confidence_id,
            0,
            subscript,
            position,
            0
        FROM
            sgn.map_version
            inner join sgn.linkage_group using (map_version_id)
            inner join sgn.marker_location using (lg_id)
            inner join sgn.marker_experiment using (location_id)
            inner join sgn.marker_alias using (marker_id)
            inner join sgn.marker_confidence using (confidence_id)
            left join sgn.marker_collectible using (marker_id)
            left join sgn.marker_collection using (mc_id)
        WHERE
            map_version.map_version_id=?
            and lg_name=?
            and preferred='t'
         ORDER BY
            position,
            confidence_id desc
    ";

    #print STDERR "MY ID: ".$self->get_id()." MY CHR NR: ".$chr_nr."\n";

    my $sth =  $self->get_dbh -> prepare($query);
    $sth -> execute($self->get_id(), $chr_nr);

    while (my ($marker_id, $marker_name, $marker_type, $confidence, $order_in_loc, $location_subscript, $offset, $loc_type) = $sth->fetchrow_array()) {
	#print STDERR "Marker Read: $marker_id\t$marker_name\t$marker_type\t$offset\n";
	my $m = CXGN::Cview::Marker -> new($chromosome, $marker_id, $marker_name, $marker_type, $confidence, $order_in_loc, $location_subscript, $offset, undef , $loc_type, 0);
	#print STDERR "dataadapter baccount = $bac_count!\n";
	if ($loc_type == 100) { $m -> set_frame_marker(); }
	$m -> set_url( $self->get_marker_link($m->get_id()));
	$self->set_marker_color($m, $self->get_legend()->get_mode());

	#print STDERR "CURRENT MODE IS: ".$self->get_legend()->get_mode()."\n";
	$chromosome->add_marker($m);

	if (exists($seq_bac{$marker_id})) {
	    #print STDERR "Adding Sequenced BAC [".($seq_bac{$marker_id}->get_name())."] to map...[$marker_id]\n";
	    $chromosome->add_marker($seq_bac{$marker_id});
	}
    }


    foreach my $mi ($self->get_map_items()) {

	my ($chr, $offset, $name) = split /\s+/, $mi;


	if (!$chr || !$offset || !$name) { next; }

	if ($chr ne $chr_nr) { next; }

	my $m = CXGN::Cview::Marker->new($chromosome);

	$m->get_label()->set_label_text($name);
	$m->set_offset($offset);
	$m->get_label()->set_hilited(1);
	$m->show_label();
	$m->get_label()->set_url('');
	$m->set_marker_name($name); # needed for proper marker ordering in the chromosome
	$chromosome->add_marker($m);


    }

    $chromosome->sort_markers();

    $chromosome -> _calculate_chromosome_length();

    return $chromosome;
}


=head2 function get_chromosome_section

  Synopsis:	my $chr_section = $map->get_chromosome_section(5, 120, 180);
  Arguments:	linkage group number, start offset, end offset
  Returns:
  Side effects:
  Description:

=cut

sub get_chromosome_section {
    my $self = shift;
    my $chr_nr = shift;     # the chromosome number
    my $start = shift;      # the start of the section in cM
    my $end = shift;        # the end of the section in cM

    my $chromosome = CXGN::Cview::Chromosome->new();

    # main query to get the marker data, including the BACs that
    # are associated with this marker -- needs to be refactored to
    # work with the materialized views for speed improvements.
    #
    my $query =
    "
        SELECT
            marker_experiment.marker_id,
            alias,
            mc_name,
            confidence_id,
            0,
            subscript,
            position,
            0,
 	    min(physical.probe_markers.overgo_probe_id),
 	    count(distinct(physical.overgo_associations.bac_id)),
 	    max(physical.oa_plausibility.plausible)
        FROM
            map_version
            inner join linkage_group using (map_version_id)
            inner join marker_location using (lg_id)
            inner join marker_experiment using (location_id)
            inner join marker_alias using (marker_id)
            inner join marker_confidence using (confidence_id)
            left join marker_collectible using (marker_id)
            left join marker_collection using (mc_id)
            LEFT JOIN physical.probe_markers ON (marker_experiment.marker_id=physical.probe_markers.marker_id)
            LEFT JOIN physical.overgo_associations USING (overgo_probe_id)
            LEFT JOIN physical.oa_plausibility USING (overgo_assoc_id)
        WHERE
            map_version.map_version_id=?
            and lg_name=?
            and preferred='t'
            -- and current_version='t'
            AND position >= ?
            AND position <= ?
        GROUP BY
            marker_experiment.marker_id,
            alias,
            mc_name,
            confidence_id,
            subscript,
            position
        ORDER BY
            position,
            confidence_id desc,
            max(physical.oa_plausibility.plausible),
            max(physical.probe_markers.overgo_probe_id)
    ";


    my $sth =  $self->get_dbh()-> prepare($query);
#    print STDERR "START/END: $start/$end\n";
    $sth -> execute($self->get_id(), $chr_nr, $start, $end);

    # for each marker, look if there is a associated fully sequenced BAC, and add that
    # as a marker of type Sequenced_BAC to the map at the right location
    #
    my $bac_status_q =
    "
        SELECT
            cornell_clone_name,
            bac_id
        FROM
            physical.bac_marker_matches
            JOIN sgn_people.bac_status using (bac_id)
        WHERE
            physical.bac_marker_matches.marker_id=?
            AND sgn_people.bac_status.status='complete'
    ";

    my $bac_status_h = $self->get_dbh()->prepare($bac_status_q);
    my $seq_bac;

    while (my ($marker_id, $marker_name, $marker_type, $confidence, $order_in_loc, $location_subscript, $offset, $loc_type, $overgo, $bac_count, $plausible, $status, $bac_name, $bac_id) = $sth->fetchrow_array()) {
	#print STDERR "Marker Read: $marker_id\t$marker_name\t$marker_type\toffset: $offset\tovergo: $overgo\tbac_count: $bac_count\tplausible: $plausible\n";
	my $seq_bac=undef;
	my $seq_bac_name="";
	my $seq_bac_id="";
	if (!$plausible || $plausible == 0)  { $bac_count = 0; }
	my $m = CXGN::Cview::Marker -> new($chromosome, $marker_id, $marker_name, $marker_type, $confidence, $order_in_loc, $location_subscript, $offset, , $loc_type, 0, $overgo, $bac_count);
	$m->set_url($self->get_marker_link($m->get_id()));
	$self->set_marker_color($m, $self->get_legend()->get_mode());
	#print STDERR "dataadapter baccount = $bac_count!\n";
	if ($loc_type == 100) { $m -> set_frame_marker(); }

	# only add the sequenced BAC information to the F2-2000.
	#
	if ($self->get_id() == CXGN::Cview::Map::Tools::find_current_version($self->get_dbh(), CXGN::Cview::Map::Tools::current_tomato_map_id())) {

	    $bac_status_h->execute($marker_id);
	    ($seq_bac_name, $seq_bac_id) = $bac_status_h->fetchrow_array();

	    # change the name to look more standard
	    #
	    if ($seq_bac_name) {
		 if ($seq_bac_name =~ m/(\d+)([A-Z])(\d+)/i) {
 		    $seq_bac_name = sprintf ("%3s%04d%1s%02d", "HBa",$1,$2,$3);
 		}
		$seq_bac = CXGN::Cview::Marker::SequencedBAC->new($chromosome, $seq_bac_id, $seq_bac_name, "", "", "", "", $offset);
	    }
	}

	# add the marker $m to the chromosome
	#
	$chromosome->add_marker($m);

	if ($m->has_overgo()) {
		$m->set_mark_color(100, 100, 100); # draw a gray circle for overgos
		$m->set_show_mark(1);
		$m->set_mark_link( "/tools/seedbac/sbfinder.pl?marker=".$m->get_marker_name()  );
	    }
	#print STDERR "# BACS: ".($m2[$i]->has_bacs())."\n";
	if ($m->has_bacs()) {
	    $m->set_mark_color(180, 0, 0); # draw a red circle for associated bacs
	    $m->set_show_mark(1);
	    $m->set_mark_link("/tools/seedbac/sbfinder.pl?marker=".$m->get_marker_name());
	}
	if (!$m->is_visible()) {
	    $m->set_show_mark(0);
	}

	# add the sequenced BAC to the chromosome
	# -url link needs to be changed
	# -add a confidence level of 3 so that it is always displayed.
	#
	if ($seq_bac) {
	    $seq_bac->set_confidence(3);
	    $seq_bac->set_url("/maps/physical/clone_info.pl?id=$seq_bac_id");
	    $chromosome->add_marker($seq_bac);
	}
    }
    $chromosome->set_section($start, $end);
    $chromosome -> _calculate_chromosome_length();



    return $chromosome;
}

=head2 function get_overview_chromosome

  Synopsis:
  Arguments:
  Returns:
  Side effects:
  Description:

=cut

sub get_overview_chromosome {
    my $self = shift;
    my $chr_nr = shift;
    my $chr = $self->get_chromosome($chr_nr);
    $chr->set_width( $self->get_preferred_chromosome_width()/2 );
    foreach my $m ($chr->get_markers()) {
	$m->hide_label();
	$m->hide_mark();
    }
    return $chr;
}

=head2 get_chromosome_connections()

 Usage:        @list = $map->get_chromosome_connections($lg_name)
 Args:         a linkage group name from the current map
 Returns:      a list of hashrefs, containing 4 keys
               map_version_id, lg_name, marker_count, short_name
               and the corresponding values
 Side Effects: the information will be used to populate the
               drop down menu in the comparative viewer.
 Example:

=cut

sub get_chromosome_connections {
    my $self = shift;
    my $chr_nr = shift;

    my $query =
	"
        SELECT
            c_map_version.map_version_id,
            c_map.short_name,
            c_linkage_group.lg_name,
            count(distinct(marker.marker_id)) as marker_count
        from
            marker
            join marker_experiment using(marker_id)
            join marker_location using (location_id)
            join linkage_group on (marker_location.lg_id=linkage_group.lg_id)
            join map_version on (linkage_group.map_version_id=map_version.map_version_id)

            join marker_experiment as c_marker_experiment on
                 (marker.marker_id=c_marker_experiment.marker_id)
            join marker_location as c_marker_location on
                 (c_marker_experiment.location_id=c_marker_location.location_id)
            join linkage_group as c_linkage_group on (c_marker_location.lg_id=c_linkage_group.lg_id)
            join map_version as c_map_version on
                 (c_linkage_group.map_version_id=c_map_version.map_version_id)
            join map as c_map on (c_map.map_id=c_map_version.map_id)
        where
            map_version.map_version_id=?
            and linkage_group.lg_name=?
            and c_map_version.map_version_id !=map_version.map_version_id
            and c_map_version.current_version='t'
        group by
            c_map_version.map_version_id,
            c_linkage_group.lg_name,
            c_map.short_name
        order by
            marker_count desc
    ";

    my $sth = $self->get_dbh() -> prepare($query);
    $sth -> execute($self->get_id(), $chr_nr);
    my @chr_list = ();

    #print STDERR "***************** Done with query..\n";
    while (my $hashref = $sth->fetchrow_hashref()) {
	#print STDERR "READING----> $hashref->{map_version_id} $hashref->{lg_name} $hashref->{marker_count}\n";
	push @chr_list, $hashref;

    }

    # hard code some connections to agp and fish maps.
    #
    my $tomato_version_id = CXGN::Cview::Map::Tools::find_current_version($self->get_dbh(), CXGN::Cview::Map::Tools::current_tomato_map_id());
    ###print STDERR $self->get_id()." VERSUS $tomato_version_id\n\n";

    if ($self->get_id() == $tomato_version_id) {

	##print STDERR "***** Map ".$self->get_id(). " pushing agp and fish map!\n\n";
	push @chr_list, { map_version_id => "agp",
			  short_name => "Tomato AGP map",
			  lg_name => $chr_nr,
			  marker_count => "?"
			  };
	push @chr_list, { map_version_id => 25,
			  short_name => "FISH map",
			  lg_name => $chr_nr,
			  marker_count => "?"
			  };
    }
    else {
	warn $self->get_id()." has no other associated maps...\n\n";
    }

    return @chr_list;
}

=head2 function has_linkage_group

  Synopsis:
  Arguments:
  Returns:
  Side effects:
  Description:

=cut

sub has_linkage_group {
    my $self = shift;
    my $candidate = shift;
    foreach my $lg ($self->get_chromosome_names()) {
	if ($lg eq $candidate) {
	    return 1;
	}
    }
    return 0;
}

=head2 function get_marker_count

accesses the database to count the marker on the given map/chromosome.

=cut

sub get_marker_count {
    my $self =shift;
    my $chr_name = shift;
    my $query = "SELECT count(distinct(location_id)) FROM sgn.map_version JOIN marker_location using (map_version_id)
                            JOIN linkage_group using (lg_id)
                      WHERE linkage_group.lg_name=? and map_version.map_version_id=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($chr_name, $self->get_id());
    my ($count) = $sth->fetchrow_array();
    return $count;

}

sub get_map_stats {
    my $self = shift;
    my $query =
    "
        select
            mc_name,
            count(distinct(marker.marker_id))
        from
            marker join marker_collectible using (marker_id)
            join marker_collection using(mc_id)
            join marker_experiment on (marker.marker_id=marker_experiment.marker_id)
            join marker_location on (marker_experiment.location_id=marker_location.location_id)
        where
            marker_location.map_version_id=?
        group by
            mc_name
    ";

    my $total_count = 0;

    my $s = "<table summary=\"\"><tr><td>&nbsp;</td><td>\# markers</td></tr>";
    my $sth = $self->get_dbh() -> prepare($query);
    $sth -> execute($self->get_id());

    my $map_name = $self->get_short_name();
    $map_name =~ s/ /\+/g;

    while (my ($type, $count)= $sth->fetchrow_array()) {
	$s .="<tr><td>$type</td><td align=\"right\"><a href=\"/search/markers/markersearch.pl?types=$type&amp;maps=$map_name\">$count</a></td></tr>";
	$total_count += $count;


    }
    $s .= "<tr><td>&nbsp;</td><td>&nbsp;</td></tr>\n";
    $s .= "<tr><td><b>Total</b>: </td><td align=\"right\"><a href=\"/search/markers/markersearch.pl?maps=$map_name\"><b>$total_count</b></a></td></tr>";
    $s .= "</table>";

    my $protocol_q = "SELECT distinct(marker_experiment.protocol), count(distinct(marker_experiment.marker_experiment_id))
                        FROM marker
                        JOIN marker_experiment using (marker_id)
                        JOIN marker_location using (location_id)
                        JOIN linkage_group using (map_version_id)
                       WHERE map_version_id=?
                       GROUP BY marker_experiment.protocol";
    my $pqh = $self->get_dbh()->prepare($protocol_q);
    $pqh ->execute($self->get_id());

    my $total_protocols = 0;
    $s.= qq { <br /><br /><table><tr><td colspan="2"><b>Protocols:</b></td></tr> };
    $s.= qq { <tr><td>&nbsp;</td><td>&nbsp;</td></tr> };
    $s.= qq { <tr><td>&nbsp;</td><td>\# markers</td></tr> };
    while (my ($protocol, $count) = $pqh->fetchrow_array()) {
	$s.= qq { <tr><td>$protocol</td><td align="right">$count</td></tr> };
	$total_protocols += $count;
    }
    $s .= qq { <tr><td colspan="2">&nbsp;</td></tr> };
    $s .= qq { <tr><td><b>Total:</b></td><td align="right"><b>$total_protocols</b></td></tr> };
    $s .= "</table>";

    return $s;
}



=head2 function has_IL

  Synopsis:
  Arguments:
  Returns:
  Side effects:
  Description:

=cut

sub has_IL {
    my $self =shift;

    if ($self->get_short_name()=~/1992|2000/) {
	#print STDERR "Map ".$self->get_short_name()." has an associated IL map.\n";
	return 1;
    }
    #print STDERR "Map ".$self->get_short_name()." does not have an associated IL map.\n";
    return 0;
}

=head2 function has_physical

  Synopsis:
  Arguments:
  Returns:
  Side effects:
  Description:

=cut

sub has_physical {
    my $self = shift;
    if ($self->get_short_name()=~/2000/) {
	return 1;
    }
    return 0;
}

=head2 function can_zoom

Whether this map support zooming in. These ones do.

=cut

sub can_zoom {
    return 1;
}

=head2 function get_marker_link

  Synopsis:
  Arguments:
  Returns:
  Side effects:
  Description:

=cut

sub get_marker_link {
    my $self =shift;
    my $id = shift;
    return "/search/markers/markerinfo.pl?marker_id=$id";
}


=head2 function set_marker_color()

  Synopsis:
  Parameters:   marker object [CXGN::Cview::Marker], color model [string]
  Returns:      nothing
  Side effects: sets the marker color according to the supplied marker color model
                the color model is a string from the list:
                "marker_types", "confidence"
  Status:       implemented
  Example:
  Note:         this function was moved to Utils from ChromosomeViewer, such that
                it is available for other scripts, such as view_maps.pl

=cut

sub set_marker_color {
    my $self = shift;
    my $m = shift;
    my $color_model = shift || '';

    if ($color_model eq "marker_types") {
	if ($m->get_marker_type() =~ /RFLP/i) {
	    $m->set_color(255, 0, 0);
	    $m->set_label_line_color(255, 0,0);
	    $m->set_text_color(255,0,0);
	}
	elsif ($m->get_marker_type() =~ /SSR/i) {
	    $m->set_color(0, 255, 0);
	    $m->set_label_line_color(0, 255,0);
	    $m->set_text_color(0,255,0);
	}
	elsif ($m->get_marker_type() =~ /CAPS/i) {
	    $m->set_color(0, 0, 255);
	    $m->set_label_line_color(0, 0,255);
	    $m->set_text_color(0,0,255);
	}
	elsif ($m->get_marker_type() =~ /COS/i) {
	    $m->set_color(255,0 , 255);
	    $m->set_label_line_color(255,0, 255);
	    $m->set_text_color(255,0,255);
	}
	else {
	    $m->set_color(0, 0, 0);
	    $m->set_label_line_color(0, 0,0);
	    $m->set_text_color(0,0,0);
	}

    }
    else {
	my $c = $m -> get_confidence();
	if ($c==0) {
	    $m->set_color(0,0,0);
	    $m->set_label_line_color(0,0,0);
	    $m->set_text_color(0,0,0);
	}
	if ($c==1) {
	    $m->set_color(0,0,255);
	    $m->set_label_line_color(0,0,255);
	    $m->set_text_color(0,0,255);

	}
	if ($c==2) {
	    $m->set_color(0,255, 0);
	    $m->set_label_line_color(0,255,0);
	    $m->set_text_color(0,255,0);
	}
	if ($c==3) {
	    $m->set_color(255, 0, 0);
	    $m->set_label_line_color(255, 0,0);
	    $m->set_text_color(255, 0,0);
	}
	if ($c==4) {
	    $m->set_color(128, 128, 128);
	    $m->set_label_line_color(128, 128, 128);
	    $m->set_text_color(128, 128, 128);
	}
    }
}

sub can_overlay {
    return 1;
}


1;
