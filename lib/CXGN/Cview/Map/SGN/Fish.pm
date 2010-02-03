

=head1 NAME
           
CXGN::Cview::Map::SGN::Fish - a class to generate cytological fish maps.
           
=head1 SYNOPSYS

 my $fish = CXGN::Cview::Map::SGN::Fish->new($dbh, 13);
 $fish->fetch_pachytene_idiogram();
 my $chr = $fish->get_chromosome(2);

 # etc...

=head1 DESCRIPTION

A class to generate cytological fish maps. Two idiograms are supported: "stack" and "dejong", which differ slightly, but no fundamentally. The "dejong" represenation was used till Oct 2009, upon Steve's request we changed to the "stack"representation by default. The third argument in the constructor can still be given as "dejong" to produce the De Jong idiograms.

=head1 AUTHOR(S)

Lukas Mueller <lam87@cornell.edu>

=head1 VERSION
 
1.1

=head1 COPYRIGHT & LICENSE

Copyright (c) 2009 Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=head1 FUNCTIONS

This class implements the following functions:

=cut

use strict;

package CXGN::Cview::Map::SGN::Fish;

use CXGN::Cview::Map;
use CXGN::Cview::Map::Tools;
use CXGN::Cview::Marker::FISHMarker;

use base qw | CXGN::Cview::Map::SGN::Genetic |;

=head2 constructor new()

  Synopsis:	my $pi = CXGN::Cview::Map::SGN::Fish->new(
                   $dbh, $id, $version );
  Arguments:	a database handle
                an id (for SGN, this is map_id=13
                a version (either "stack" or "dejong", used
                to draw the pachytene representation accordingly).
  Returns:	a CXGN::Cview::Map::SGN::Fish object

=cut

sub new {
    my $class = shift;
    my $dbh = shift;
    my $id = shift;
    my $pachytene_version = shift;


    my $self = $class->SUPER::new($dbh, $id);
    $self->set_id($id);
    $self->{pachytene_version} = $pachytene_version;
    $self->set_preferred_chromosome_width(12);
    $self->set_chromosome_names("1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12");
    $self->set_chromosome_count(12);
    $self->fetch_pachytene_idiograms();
    $self->set_units("%");
    $self->set_legend(CXGN::Cview::Legend->new());
    return $self;
}

=head2 function fetch_pachytene_idiogram()

  Synopsis:	$pi->fetch_pachytene_idiogram
  Arguments:	loads the pachytene idiogram from a standard location.
  Returns:	nothing
  Side effects:	the idiogram definition fetched will be the 
                basis for the chromosome rendering
  Description:	

=cut

sub fetch_pachytene_idiograms {
    my $self = shift;
    my $vhost_conf=CXGN::VHost->new();

    my $file_name = "pachytene_stack.txt";

    if (defined($self->{pachytene_version}) && $self->{pachytene_version} =~/dejong/i ) { 
	$file_name = "pachytene_tomato_dapi.txt";
    }
	
    my $data_folder=$vhost_conf->get_conf('basepath').$vhost_conf->get_conf('documents_subdir');
    open (F, "<$data_folder/cview/pachytene/".$file_name) || die "Can't open pachytene def file";
    my %chr_len=();;
    @{$self->{pachytene_idiograms}} = ();
    foreach my $n ($self->get_chromosome_names()) { 
	#print STDERR "Generatign pachytene idogram $n...\n";
	push @{$self->{pachytene_idiograms}}, CXGN::Cview::Chromosome::PachyteneIdiogram->new();
    }
    my $short_arm=0;
    my $long_arm=0;
    
    my $old_chr = "";
    my ($chr, $type, $start, $end) = (undef, undef, undef, undef);
    while (<F>) { 
	chomp;
	
	# skip comment lines.
	if (/^\#/) { next(); }
	($chr, $type, $start, $end) = split/\t/;
	
	if ($chr ne $old_chr) { 
	    $chr_len{$old_chr}=($short_arm + $long_arm);
	    #print STDERR "Fish map: $old_chr is $chr_len{$old_chr} long...\n";
	    $short_arm = 0;
	    $long_arm = 0;
	    $old_chr = $chr;
	}
	
	#print STDERR "Adding feature $type ($start, $end)\n";
	$self->{pachytene_idiograms}->[$chr-1] -> add_feature($type, $start, $end);
	
	if ($type eq "short_arm") { 
	    $short_arm = abs($start) + abs($end);
	}
	if ($type eq "long_arm") {
	    $long_arm = abs($start) + abs($end);
	}
	
    }
    # deal with the last entry
    $chr_len{$chr}=($short_arm + $long_arm);
    #print STDERR "Fish map: $old_chr is $chr_len{$old_chr} long...\n";

    my @chr_len = ();
    foreach my $n ($self->get_chromosome_names()) { 
	push @chr_len, $chr_len{$n};
    }
    #print STDERR "Setting chromosome lengths to : ".(join " ", @chr_len)."\n";
    $self->set_chromosome_lengths(@chr_len);
    #print STDERR "Getting chromosome lengths: ".(join " ", $self->get_chromosome_lengths())."\n";
    
}



sub get_pachytene_idiogram { 
    my $self = shift;
    my $chr_index = shift;
    return $self->{pachytene_idiograms}->[$chr_index];
}

=head2 function get_chromosome()
    
See parent class for description
    
=cut
    
sub get_chromosome {
    my $self = shift;
    my $chr_nr = shift;
    
    #print STDERR "generating fish chromosome $chr_nr...\n";

    my $chromosome = $self->get_pachytene_idiogram($chr_nr-1);
    
    #print STDERR "Fetching $chromosome_number pachytene\n";
    
    
    # The following query is a composition of 3 subqueries (look for the 'AS'
    # keywords), joined using the clone_id.  Here's what the subqueries do:
    #
    # * clone_id_and_percent: gets the average percent distance from the
    #   centromere as a signed float between -1.0 and +1.0, for each
    #   BAC on a given chromosome.  This is done by first computing the
    #   average absolute distance from the centromere (signed, in um),
    #   and then dividing by the length of the arm that the average
    #   would be located on.
    #
    # * min_marker_for_clone: finds one marker associated with the BAC
    #   (if any).
    #
    # * clone_info: finds the library shortname and clone name components.
    my $query = "
   SELECT shortname, clone_id, platenum, wellrow, wellcol, percent, marker_id
     FROM (SELECT clone_id, (CASE WHEN absdist < 0
                                       THEN absdist / short_arm_length
                                       ELSE absdist / long_arm_length END) AS percent
             FROM (SELECT clone_id, chromo_num,
                          AVG(percent_from_centromere * arm_length *
                              CASE WHEN r.chromo_arm = 'P' THEN -1 ELSE 1 END)
                              AS absdist
                     FROM fish_result r
                     JOIN fish_karyotype_constants k USING (chromo_num, chromo_arm)
                    WHERE chromo_num = ?
                    GROUP BY clone_id, chromo_num) AS clone_id_and_absdist
             JOIN (SELECT k1.chromo_num, k1.arm_length AS short_arm_length,
                          k2.arm_length AS long_arm_length
                     FROM fish_karyotype_constants k1
                     JOIN fish_karyotype_constants k2 USING (chromo_num)
                    WHERE k1.chromo_arm = 'P' AND k2.chromo_arm = 'Q')
                   AS karyotype_rearranged USING (chromo_num))
       AS clone_id_and_percent

LEFT JOIN physical.bac_marker_matches ON (clone_id=bac_id)

LEFT JOIN (SELECT shortname, clone_id, platenum, wellrow, wellcol
             FROM genomic.clone
             JOIN genomic.library USING (library_id))
       AS clone_info USING (clone_id)
GROUP BY clone_id, shortname, platenum, wellrow, wellcol, percent, marker_id ORDER BY percent
";

    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($chr_nr);
    while (my ($library_name, $clone_id, $platenum, $wellcol, $wellrow, $percent, $marker_id) = $sth->fetchrow_array()) {
	my $offset = 0;
	my $factor = 0;
	$offset = $percent * 100;

	print STDERR "OFFSET $offset \%\n";

	my $clone_name = CXGN::Genomic::Clone->retrieve($clone_id)->clone_name();
	
	my $m = CXGN::Cview::Marker::FISHMarker -> new($chromosome, $marker_id, $clone_name, "", 3, $offset+100, "", $offset );
	$m -> set_url("/maps/physical/clone_info.pl?id=".$clone_id);
	$chromosome->add_marker($m);
    }
    return $chromosome;
}

=head2 function get_overgo_chromosome()

See parent class for description

=cut

sub get_overgo_chromosome {
    my $self = shift;
    my $chr_nr = shift;
    my $chr = $self->get_chromosome($chr_nr);

    $chr->set_vertical_offset_centromere();
    return $chr;
    
}

=head2 function get_chromosome_connections()

See parent class for description

=cut

sub get_chromosome_connections {
    my $self = shift;
    my $chr_nr = shift;
    my @chr_list = ();
    my $map_version_id = CXGN::Cview::Map::Tools::find_current_version($self->get_dbh(), CXGN::Cview::Map::Tools::current_tomato_map_id );
    #print STDERR "Map_version_id is : $map_version_id. \n";
    push @chr_list, { map_version_id=>$map_version_id, short_name=>"F2-2000", lg_name=>$chr_nr, marker_count=>"?" };
    return @chr_list;
    
}


=head2 function get_preferred_chromosome_width()

This function returns 12. Yep.

=cut

sub get_preferred_chromosome_width {
    return 12;
}

=head2 function collapsed_marker_count()

This function returns a large number (hard-coded) to make sure that no fish experiments are hidden from the chromosome view (if the number of fish experiments becomes really large this will need to be revisited).

=cut

sub collapsed_marker_count { 
    return 2000;
}

sub can_zoom { 
    return 0;
}

=head2 function get_map_stats()

See parent class for description.

=cut

sub get_map_stats {
    my $self = shift;
    my $query = "SELECT count(distinct(clone_id)) FROM sgn.fish_result";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    return "Total number of fished clones: $count\n";
}

=head2 function get_marker_count()

See parent class for description.

=cut

sub get_marker_count {
    my $self = shift;
    my $chr_nr = shift;
    my $query = "SELECT count(distinct(clone_id)) FROM sgn.fish_result WHERE chromo_num=?";
    my $sth = $self->get_dbh()->prepare($query);
    $sth->execute($chr_nr);
    my ($count) = $sth->fetchrow_array();
    return $count;
    
}

return 1;
