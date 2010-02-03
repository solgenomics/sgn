use CGI;
use CXGN::DB::Connection;
use CXGN::Phenome::GenericGenePage;

my ($locus_id) = CGI->new->param('locus_id')
    or do { print "no locus_id passed"; exit };

print "Content-Type: text/xml\n\n";

my $xml_page = CXGN::Phenome::GenericGenePage
    ->new( -id => $locus_id,
	   -dbh => CXGN::DB::Connection->new
	  );

print $xml_page->render_xml();

