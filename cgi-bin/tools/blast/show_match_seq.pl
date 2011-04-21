use CatalystX::GlobalContext qw( $c );

=head1 NAME

show_match_seq.pl - a simple script to show the entire sequence of a
match in a blast database with optional highlighting of the matched
region

=head1 DESCRIPTION

This script shows a webpage with the sequence from a blast database
for a specific id, using CXGN::BlastDB. This is the script that should
be called if the CXGN::Tools::Identifiers cannot determine an
appropriate link, so that the users still can get at the matched
sequence, instead of uselessly defaulting to Genbank.

Page arguments:

=over 10

=item id

The id of the sequence [string], as it appears in the database (best
retrieved from a blast report).

=item blast_db_id

The id [int] of the blast database file for CXGN::BlastDB.

=item hilite_coords

a list of start and end coordinates, of the form:

start1-end1,start2-end2,start3-end3

=item format

either "text" or "html" to output fasta text or a nicely ;-) formatted
html page.

=back

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

Robert Buels <rmb32@cornelle.edu>

=cut

use strict;
use warnings;

use CGI ();

use CXGN::BlastDB;
use CXGN::Tools::Text qw/ sanitize_string /;
use CXGN::MasonFactory;

use CXGN::Page::FormattingHelpers qw | info_section_html html_break_string html_string_linebreak_and_highlight | ;

my $cgi = CGI->new;

#get params
my ( $id            ) = $cgi->param( 'id'            );
my ( $blast_db_id   ) = $cgi->param( 'blast_db_id'   );
my ( $format        ) = $cgi->param( 'format'        );
my ( $hilite_coords ) = $cgi->param( 'hilite_coords' );

#sanitize params
$format      ||= 'html';
$blast_db_id +=  0;
$id          =   sanitize_string( $id );

$c->forward_to_mason_view('/blast/show_seq/input.mas') unless $blast_db_id && defined $id;

# parse the coords param
my @coords =
    map {
        my ($s, $e) = split "-", $_;
        defined $_ or die 'parse error' for $s, $e;
        [ $s, $e ]
    }
    grep length,
    split ',',
    ( $hilite_coords || '' );

#die("hilite_coords $hilite_coords. ".(join ",", @coords)."\n");

# look up our blastdb
my $bdbo = CXGN::BlastDB->from_id( $blast_db_id )
    or $c->throw( is_error => 0,
                  message => "The blast database with id $blast_db_id could not be found (please set the blast_db_id parameter).");

my $seq = $bdbo->get_sequence( $id ) # returns a Bio::Seq object.
    or $c->throw( is_error => 0,
                  message => "The sequence could not be found in the blast database with id $blast_db_id.");

# dispatch to the proper view
if ( $format eq 'html' ) {
    my $view_link     = do { $cgi->param( format => 'fasta_text'); '?'.$cgi->query_string };
    my $download_link = do { $cgi->param( format => 'fasta_file'); '?'.$cgi->query_string };

    $c->forward_to_mason_view(
        '/blast/show_seq/html.mas',
        seq              => $seq,
        highlight_coords => \@coords,
        source           => '"'.$bdbo->title.'" BLAST dataset ',
        format_links     => [
            ( $seq->length > 500_000 ? () : [ 'View as FASTA' => $view_link ] ),
            [ 'Download as FASTA' => $download_link ],
           ],
        blast_url => '/tools/blast/index.pl',
       );

} elsif( $format eq 'fasta_file' || $format eq 'fasta_text' ) {

    require Bio::SeqIO;

    print "Content-Type: text/plain\n";
    my $attachment = $format eq 'fasta_file' ? 'attachment;' : '';
    print "Content-Disposition: $attachment filename=$id.fa\n";
    print "\n";
    Bio::SeqIO->new( -fh => \*STDOUT, -format => 'fasta' )
              ->write_seq( $seq )
}


