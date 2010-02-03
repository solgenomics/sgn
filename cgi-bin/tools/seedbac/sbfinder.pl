
=head1 NAME

sbfinder.pl - a web script that displays potential seedbacs given a marker of the F2-2000 map

=head1 DESCRIPTION

sbfinder.pl will query the physical database bac_marker_matches materialized view for information about BAC - genetic map associations. There are three association types: overgo (experimentally determined associations), computational (associations determined by blast) and manual associations. (the materialized view is created from data of other tables in the physical and sgn databases using the script add_bac_marker_matches_view.pl (found in sgn-tools/stable/physical_tools/bin/ ). See perldoc of that script for more information.

Note: As of 6/2006, the overgo analysis has only been performed on the HindIII library. The computational analysis was done on the HindIII, EcoRI, and MboI library, based on BAC end sequence data (a small part of the normally not known full BAC sequence). Manual annotations are made based on publications and other experimental data.

=head1 AUTHOR(S)

Lukas Mueller (lam87@cornell.edu)

=cut


use CXGN::Page;
use strict;
use DBI;
use CXGN::DB::Connection;

my $sbf = seedbac_finder -> new();
$sbf -> get_args();
if (!$sbf -> has_data()) {
    $sbf -> input_page();
}
else {
    $sbf -> display_results();
}
$sbf -> clean_up();


package seedbac_finder;

1;

sub new {
    my $class = shift;
    my $args = {};
    my $self = bless $args, $class;
    our $page = CXGN::Page->new();
    $self->{page} = $page;
    $self->{dbh} = CXGN::DB::Connection->new();
    return $self;
}

sub has_data {
    my $self = shift;
    if ($self->get_marker()) { 
	return 1;
    }
    else {
	return 0;
    }
}

sub set_marker {
    my $self = shift;
    $self->{marker} = shift;
}

sub get_marker {
    my $self = shift;
    return $self->{marker};
}

sub input_page {
    my $self=shift;
    $self->{page}->header();
   
    $self->input_box();

    $self->{page}->footer();
	
}

sub input_box {
    my $self = shift;
    my $marker = $self->get_marker();
    print <<HTML;
    
    <h3>Seedbac finder</h3>
    This tool will suggest a seed bac given a marker name from the tomato F2-2000 map. Experimental (overgo), computational (blast) and manual (curated from experimental evidence) associations are reported.<br /><br />
	<form action=\"sbfinder.pl\">
	Marker name: <input name="marker"  value="$marker" />
	<input type="submit" value="Submit" />
	</form>
	
HTML

}

sub get_args {
    my $self = shift;
    
    my ($marker) = $self->{page}->get_arguments("marker");
    $self->set_marker($marker);
     
}

sub display_results {
    my $self = shift;
    my %bacs = ();
    (@{$bacs{overgo}}) = $self->get_bacs("overgo");
    (@{$bacs{computational}}) = $self->get_bacs("computational");
    (@{$bacs{manual}}) = $self ->get_bacs("manual");
    
    $self->{page}->header();

    $self->input_box();

    print "<br /><h3>Suggested Seedbacs for marker ".$self->get_marker()."</h3>";
    
    print qq { <table cellspacing="10"> };
    print "<tr><td>BAC name</td><td>estimated length</td><td>contig name</td><td>contig size</td><td>top pick</td></tr>";
    foreach my $a_type ("overgo", "computational", "manual") { 
	print qq { <tr><td colspan="4"><b>$a_type associations</b></td></tr> };
	if (!@{$bacs{$a_type}}) { 
	    print qq { <tr><td colspan="4">None found.</td></tr> };
	}
	foreach my $b (@{$bacs{$a_type}}) {
	    
	    my ($bac_id, $bac, $len, $name, $contigs) = split /\t/, $b;
	    my $toppick="<td>&nbsp;</td>";
	    my $contig_id=0;
	    if ($name =~ /ctg(\d+)/) { $contig_id = $1; }
	
	    if ($len>120000 && $contigs > 0) { $toppick="<td bgcolor=00FF00>&nbsp;</td>"; }
	    print qq{ <tr><td><B><a href="/maps/physical/clone_info.pl?id=$bac_id">$bac</a></B></td><td>$len</td><td><a href="http://www.genome.arizona.edu//WebAGCoL/WebFPC/WebFPC_Direct_v2.1.cgi?name=tomato&contig=$contig_id">$name</a><td>$contigs</td>$toppick</tr> };
	}
    }
    print "</table>";
    $self->{page}->footer();
    
}

sub get_bacs {

    my $self = shift;
    my $marker_name = $self->get_marker();
    my $association_type = shift;

#    my $physical = $self->{dbh}->qualify_schema('physical');
    
#    my $query = "SELECT cornell_clone_name, estimated_length, contig_name, number_of_contigs, number_of_markers FROM $physical.bac_marker_matches WHERE marker_name=? GROUP BY bac_id, cornell_clone_name, estimated_length, contig_name, number_of_contigs, number_of_markers ORDER BY estimated_length desc, number_of_contigs";
    my $query = "SELECT distinct bac_id, arizona_clone_name, estimated_length, contig_name, number_of_bacs, lg.lg_order, bmm.position, alias, marker_id  FROM physical.bac_marker_matches AS bmm inner join linkage_group as lg using(lg_id) WHERE alias ilike ? AND association_type=? ORDER BY lg.lg_order, bmm.position, alias, estimated_length desc, number_of_bacs desc, arizona_clone_name, contig_name desc";

    my $sth = $self->{dbh}->prepare($query);
    $sth->execute($marker_name, $association_type);

    my @bacs;
    while (my @line = $sth -> fetchrow_array()) {

 	my $line = join ("\t", @line);

 	push @bacs, $line;
     }

     return @bacs;
}

sub clean_up {
    my $self = shift;
#    $self->{dbh}->disconnect();
}

