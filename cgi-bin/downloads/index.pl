
use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ page_title_html info_section_html /;

my $page = CXGN::Page->new("SGN software downloads", "Lukas");

my $title = page_title_html("Download SGN software",);

$page->header("Downloads", $title);

my $contents ="";

$contents .= info_section_html(title=>"SGN Comparative Viewer", contents=><<CVIEW);

The SGN Comparative Viewer Application. <br /><br />
Download  [<a href="ftp://ftp.sgn.cornell.edu/programs/cview/">FTP</a>]

CVIEW

$contents .= info_section_html(title=>"PerlCyc", contents=><<PERLCYC);

PerlCyc is a Perl interface for <a href="http://bioinformatics.ai.sri.com/ptools/">Pathway Tools software</a>. It allows internal Pathway Tools Lisp functions to be accessed through Perl. <a href="perlcyc.pl">More...</a><br /><br />

    Download [<a href="ftp://ftp.sgn.cornell.edu/programs/perlcyc/">FTP</a>]

PERLCYC


$contents .= info_section_html(title=>"JavaCyc", contents=><<JAVACYC);

JavaCyc is a Java interface for Pathway Tools software. It allows internal Pathway Tools Lisp function to be accessed through Java.<br /><br />

Download [<a href="ftp://ftp.sgn.cornell.edu/programs/javacyc/">FTP</a>]

JAVACYC

    print $contents;

$page->footer();


