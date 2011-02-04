
=head1 NAME

chr_sbfinder.pl - a script that finds the seed bacs on a given chromosome with some options

=head1 DESCRIPTION

chr_sbfinder.pl will display and input form if no arguments are given, or query the database for seedbacs on a given chromosome if there are arguments. 

overgo associations are generated using the scripts in /sgn-tools/stable/physical_tools/bin/

computational associations are generated using parsed BLAST reports and are loaded into the database using the script in /sgn-tools/stable/physical_tools/bin/load_computational_associations.pl 

manual associations are currently entered using SQL commands.

This script relies on a materialized view of the information in the tables cited above. The view is generated using the script /sgn-tools/stable/physical_tools/bin/add_bac_marker_view.pl .

=head1 AUTHORS

Lukas Mueller (lam87@cornell.edu),
Beth Skwarecki (eas68@cornell.edu)

=cut

use strict;

use CXGN::Page;
use CXGN::Map::Tools;
use CXGN::DB::Connection;
use CXGN::Genomic::Clone;

my $sbf = chr_seedbac_finder -> new();

$sbf -> get_args();
if (!$sbf -> has_data()) {
    #print STDERR "No data supplied...\n";
    $sbf -> input_page();
}
else {
    if ($sbf->get_query("overgo")) { 
	$sbf -> get_overgo_associations(); 
    }
    if ($sbf->get_query("computational")) { 
	$sbf -> get_computational_associations();
    }
    if ($sbf->get_query("manual")) { 
	$sbf-> get_manual_associations();
    }
    $sbf -> display_results();
}

package chr_seedbac_finder;

return 1;

sub new {
    my $class = shift;
    my $args = {};
    my $self = bless $args, $class;
    our $page = CXGN::Page->new();
    $page->header();
    $self->{page} = $page;
    $self->set_dbh( CXGN::DB::Connection->new() );
    return $self;
}

sub has_data {
    my $self = shift;
    if ($self->{chr}) { 
	return 1;
    }
    else {
	return 0;
    }
}

sub input_page {
    my $self=shift;
    #$self->{page}->header();
   
    $self->input_box();

    $self->{page}->footer();	
}

sub input_box {
    my $self = shift;

    print <<HTML;
    
    <h3>Seedbac finder</h3>
    This tool lists all anchored bacs for a given chromosome on the tomato F2-2000 map to help identify seed bacs.<br /><br />
    <form action="#">
      Chromosome: <select name="chr">
	
HTML
      for(my $i=1; $i<=12; $i++){
	  print "<option value=\"$i\">$i</option>";
      }

    print <<HTML;
      </select>

      Marker minimal confidence: <select name="confidence">
      <option value=\"0\">I</option>
      <option value=\"1\">ILOD(2)</option>
      <option value=\"2\">CLOD(3)</option>
      <option value=\"3\">FLOD(3)</option>
      </select>
      
      <!-- Return <input type="text" name="nr_bacs" value="all" size="3" /> BACs per anchor point. -->
      <br /><br />
      <input type="checkbox" name="show_overgo" checked="checked" /> Retrieve experimental (overgo) associations<br />
      <input type="checkbox" name="show_computational" /> Retrieve computational associations<br />
      <input type="checkbox" name="show_manual" /> Retrieve manual associations<br />

      <br />
      <input type="checkbox" name="text_output" /> Output as text<br />
      <br />
      &nbsp;&nbsp;<input type="submit" value="Submit" />
      </form>
	
HTML

}

sub get_args {
    my $self = shift;
    my $nr_bacs_input = 0;
    my $chr = 0; my $confidence = -1;
    my ($show_overgo, $show_computational, $show_manual);
    ($chr, $confidence, $nr_bacs_input, $self->{text_output}, $show_overgo, $show_computational, $show_manual) = $self->{page}->get_arguments("chr", "confidence", "nr_bacs", "text_output", "show_overgo", "show_computational", "show_manual");
    chomp($nr_bacs_input);
    $self->set_chr($chr);
    $self->set_confidence($confidence);
    $self->{nr_bacs} = int($nr_bacs_input);
    if ($self->{nr_bacs} != $nr_bacs_input && (!($nr_bacs_input eq "all" || $nr_bacs_input eq ""))) { $self->{page}->error_page("Number of BACs returned has to be numeric."); }
    if ($show_overgo) { $self->add_query("overgo"); }
    if ($show_computational) { $self->add_query("computational"); }
    if ($show_manual) { $self->add_query("manual"); }
}


sub display_results { 
    my $self = shift;
    if ($self->{text_output}) { 
	$self->display_results_text();
    }
    else { $self->display_results_html(); }
}

sub display_results_text {
    my $self = shift;
#print "Pragma: \"no-cache\"\nContent-Disposition: filename=sequences.fasta\nContent-type: application/data\n\n";
    #$self->{page}->{request}->send_http_header("text/plain");
    print "<pre>";
    print $self->{text};
    print "</pre>";
   
}

sub display_results_html {
    my $self = shift;
    
    #$self->{page}->header();

    $self->input_box();

    print "<br /><h3>Seedbacs for chromosome ".$self->get_chr()."</h3>";
    
    print "Only unambiguous matches are shown. ";
    if ($self->{nr_bacs}) { print "$self->{nr_bacs} shown per anchor point."; }
    else { print "All BACs listed for each marker."; }
    print "<br />\n";
    #if (! @bacs) { print "No bacs found or marker does not exist.\n"; } 

    print qq { <table cellspacing="5" cellpadding="0" border="0"> };
    print qq { <tr><td>Marker</td><td>confidence</td><td>offset (cM)</td><td>BAC name</td><td>estimated length</td><td>contig name</td><td>contig size</td><td>top pick</td><td>type</td></tr> };
    
    print $self->{html};
    
    print "</table>";
    $self->{page}->footer();
    
}

sub format_html { 
    my $self = shift;
    my ($marker_id, $marker_name, $confidence, $offset, $bac, $len, $name, $contigs, $type) = @_;

    my $s = "";
    my $count = 0;
    my @confidence = ( "I", "ILOD2", "CFLOD3", "F");

	if (!$self->{bgcolor}) { $self->{bgcolor}="#ffffff"; }
	my $toppick="&nbsp;";
	if ($count ==1) { $toppick=qq{<img src="/img/checkmark.jpg" alt="" />}; }
	$s .= qq { <tr bgcolor="$self->{bgcolor}"><td><a href="/search/markers/markerinfo.pl?marker_id=$marker_id">$marker_name</a> [<a href="/tools/seedbac/sbfinder.pl?marker=$marker_name">all</a>][<a href="/cview/view_chromosome.pl?chr_nr=$self->{chr}&amp;hilite=$marker_name">View</a>]</td><td align="center">$confidence[$confidence]</td><td align="center">$offset</td><td><b><a href="/maps/physical/clone_info.pl?cu_name=$bac">$bac</a></b></td><td align="center">$len</td><td align="center">$name</td><td align="center">$contigs</td><td bgcolor="#FFFFFF">$toppick</td><td>$type</td></tr> };
    
    return $s;
}

sub format_text {
    my $self = shift;
    my $marker_name = shift;
    my $confidence = shift;
    my $offset = shift;
    my @confidence = ( "I", "ILOD2", "CFLOD3", "F");
    my @bacs = @_;
    my $s = "";
    foreach my $b (@bacs) {
	my ($bac, $len, $name, $contigs) = split /\t/, $b;
	if (!$contigs) { $contigs = ""; } # avoid undefined blabla errors
	if (!$name) { $name = ""; }
	$s.= "$marker_name\t$confidence[$confidence]\t$offset\t$bac\t$len\t$name\t$contigs\n";
    }
    return $s;
}

sub toggle_bgcolor { 
    my $self = shift;
    my $color1 = "#FFFFFF";
    my $color2 = "#DDDDDD";
    my $color3 = "#FF0000";
    if (!$self->{bgcolor}) { $self->{bgcolor}=$color3; }
    if ($self->{bgcolor} eq $color1) { $self->{bgcolor} = $color2; } 
    else { $self->{bgcolor} = $color1; }
    
}

sub get_overgo_associations { 
    my $self = shift;

    $self ->{html}.= qq { <tr><td colspan="10"><h3>Experimental (overgo) Associations</h3></td></tr> };

    my $results = $self->get_associations("overgo");

    foreach my $row (@$results){
      $self->{html}.=$self->format_html(@$row,"overgo");
      $self->{text}.=$self->format_text(@$row, "overgo");
    }

}

sub get_computational_associations { 
    my $self = shift;
    my $physical = $self->get_dbh()->qualify_schema("physical");
    my $genomic  = $self->get_dbh()->qualify_schema("genomic");
    my $current_tomato_map_id = CXGN::Map::Tools::current_tomato_map_id;
    $self ->{html}.= qq { <tr><td colspan="10"><h3>Computational Associations</h3></td></tr> };
#     my $sth = $self->get_dbh()->prepare("
#        SELECT distinct(marker_alias.marker_id), max(marker_alias.alias), max(confidence_id), max(position), max(library.shortname||platenum||clone.wellrow||clone.wellcol), max(estimated_length), max('?'), 0, linkage_group.lg_order
#        FROM $physical.computational_associations JOIN $genomic.clone using (clone_id) 
#        JOIN $genomic.library using (library_id)
#        JOIN marker_alias USING (marker_id)
#        JOIN marker_experiment ON ($physical.computational_associations.marker_id=marker_experiment.marker_id)
#        JOIN marker_location using (location_id)
#        JOIN map_version using (map_version_id)
#        JOIN linkage_group ON (linkage_group.map_version_id=map_version.map_version_id)
#        WHERE linkage_group.lg_name=?
#          AND marker_location.confidence_id>=?
#          AND map_version.map_id=$current_tomato_map_id
#          AND map_version.current_version='t' 
#          AND marker_alias.preferred='t'
#        GROUP BY marker_alias.marker_id, linkage_group.lg_order
# -- ,marker_alias.alias, confidence_id, position, clone_id, estimated_length, linkage_group.lg_order, library.shortname, clone.wellrow, clone.wellcol
#        ORDER BY linkage_group.lg_order"
# 			      );

#     $sth->execute($self->get_chr(), $self->get_confidence());

    my $results = $self->get_associations("computational");

    foreach my $result (@$results) { 
#	$self->{html}.="*";
	$self->{html}.=$self->format_html(@$result,"computational");
	$self->{text}.=$self->format_text(@$result,"computational");
	
    }
}

=head2 get_manual_associations

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_manual_associations {
    my $self = shift;

    $self ->{html}.= qq { <tr><td colspan="10"><h3>Manual Associations</h3></td></tr> };

    my $results = $self->get_associations("manual");

    foreach my $row (@$results){
      $self->{html}.=$self->format_html(@$row,"overgo");
      $self->{text}.=$self->format_text(@$row, "overgo");
    }
}

=head2 function get_associations

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_associations {
    my $self = shift;
    my $association_type = shift;

    my $physical = $self->get_dbh()->qualify_schema('physical');

    my $MAP_ID = CXGN::Map::Tools::current_tomato_map_id();

    my $limit_string = "";
    if ($self->{nr_bacs}) { $limit_string = "limit $self->{nr_bacs}"; }

    my $query =  "SELECT distinct marker_id, alias, confidence_id, bmm.position, arizona_clone_name, estimated_length, contig_name, number_of_bacs as mc, lg.lg_order FROM physical.bac_marker_matches AS bmm join linkage_group as lg using(lg_id) WHERE confidence_id >= ? AND lg.lg_name = ? AND association_type=? ORDER BY lg.lg_order, bmm.position, alias, estimated_length desc, number_of_bacs desc, contig_name";

    my $sth = $self->get_dbh()->prepare($query);

    $sth->execute($self->get_confidence(), $self->get_chr(), $association_type);

    my $results = $sth->fetchall_arrayref();
    return $results;
}

=head2 function get_confidence

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_confidence { 
    my $self=shift;
    return $self->{confidence};
}

=head2 function set_confidence

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub set_confidence { 
    my $self=shift;
    $self->{confidence}=shift;
}

=head2 function get_chr

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_chr { 
    my $self=shift;
    return $self->{chr};
}

=head2 function set_chr

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub set_chr { 
    my $self=shift;
    $self->{chr}=shift;
}

=head2 function get_dbh

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub get_dbh { 
    my $self=shift;
    return $self->{dbh};
}

=head2 function set_dbh

  Synopsis:	
  Arguments:	
  Returns:	
  Side effects:	
  Description:	

=cut

sub set_dbh { 
    my $self=shift;
    $self->{dbh}=shift;
}

=head2 add_query

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub add_query {
    my $self = shift;
    my $query_type = shift;
    $self->{queries}->{$query_type}=1;
}

=head2 get_queries

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_queries {
    my $self = shift;
    return keys (%{$self->{queries}});
   
}

=head2 get_query

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_query {
    my $self = shift;
    my $query_type = shift;
    if (exists($self->{queries}->{$query_type}) ) { 
	return $self->{queries}->{$query_type};
    }
    else { return undef; }
}


