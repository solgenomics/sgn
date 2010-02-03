
=head1 NAME

show_match_seq.pl - a simple script to show the entire sequence of a match in a blast database with optional highlighting of the matched region

=head1 DESCRIPTION

This script shows a webpage with the sequence from a blast database for a specific id, using CXGN::BlastDB. This is the script that should be called if the CXGN::Tools::Identifiers cannot determine an appropriate link, so that the users still can get at the matched sequence, instead of uselessly defaulting to Genbank. 

Page arguments:

=over 10

=item id

The id of the sequence [string], as it appears in the database (best retrieved from a blast report).

=item blast_db_id

The id [int] of the blast database file for CXGN::BlastDB.

=item hilite_coords

a list of start and end coordinates, of the form: 

start1-end1,start2-end2,start3-end3

=item format

either "text" or "html" to output fasta text or a nicely ;-) formatted html page.

=back 

=head1 Implementation 

Calls a mason component, /tools/sequence.mas, to display the sequence.

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

use strict;

use CXGN::Page;
use CXGN::BlastDB;
use CXGN::Tools::Text;
use CXGN::MasonFactory;
use CXGN::Tools::Run;
use CXGN::Page::FormattingHelpers qw | info_section_html html_break_string html_string_linebreak_and_highlight | ;

my $page = CXGN::Page->new("BLAST Sequence Detail Page", "Lukas");


my ($id, $blast_db_id, $format, $hilite_coords) = $page->get_arguments("id", "blast_db_id", "format", "hilite_coords");

if (!$blast_db_id) { 
    show_form($page);
    return;
}

if (!$format) { 
    $format = 'html';
}

$id = CXGN::Tools::Text::sanitize_string($id);
$blast_db_id = CXGN::Tools::Text::sanitize_string($blast_db_id);

my @coords = ();
my @start_end = split ",", $hilite_coords;
foreach my $se (@start_end) { 
    my ($s, $e) = split "-", $hilite_coords;
    push @coords, [ $s-1, $e-1 ];
}

my $bdbo;
my $seq;
#$page->message_page("hilite_coords $hilite_coords. ".(join ",", @coords)."\n");

$bdbo = CXGN::BlastDB->from_id($blast_db_id);

if (!defined($bdbo)) { 
    $page->message_page("The blast database with the id $blast_db_id could not be found (please set the blast_db_id parameter).");
}

$seq = $bdbo->get_sequence($id); # returns a Bio::Seq object.

if (!$seq) { 
    $page->message_page("The sequence could not be found in the blast database with id $blast_db_id.\n");
}


my $output = CXGN::MasonFactory->bare_render('/tools/sequence.mas', seq => $seq, coords => \@coords, format=>$format, title=>$id." from BLAST dataset '".$bdbo->title()."'" );

if ($format eq 'html') { 
    $page->header();
    
    print qq | <a href="?blast_db_id=$blast_db_id&amp;id=$id&amp;format=text">Output as text</a><br />\n |;
    
    
    print $output;
    
    $page->footer();
}
else { 
     print "Content-Type: text/html\n\n";
    print $output;
}




sub show_form { 
    my $page = shift;
    
    $page->header();
    
    print <<HTML;
    
    <h1>Display sequence from BLAST database</h1>

	<form>
	<table cellpadding="5" cellspacing="5" alt=""><tr>
	<td><b>Dataset</b></td><td> <select name="blast_db_id">
	<option value="93">Tomato WGS Sequence</option>
	<option value="56">Tomato BAC contigs</option>
	</select></td></tr>
	
	<td><b>Id</b></td><td> <input type="text" name="id" size="10"/><br /></td></tr>

	<tr><td colspan="3"><b>Highlight coordinates (enter as: 1-100,200-300)</b></td></tr>
	<tr><td><b>Coordinates: </b></td><td> <input type="text" name="hilite_coords" size="10" /><br /></td></tr>
	
	<tr><td><b>Format</b></td><td><select name="format"><option value="html">html</option><option value="text">text</option></select></td></tr>
	
	</table>
	
	<input type="submit"  />
	</form>
	
	
HTML

     $page->footer();

}






