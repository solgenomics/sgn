use strict;

use DBIx::Class;
use CXGN::Marker::SNP::Snp;
use CXGN::Marker::SNP::Schema;
use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::VHost;
use CXGN::Scrap;
use CXGN::Page::FormattingHelpers qw /info_section_html
                                      page_title_html/;

#Start a new SGN page
my $page = CXGN::Page->new("SGN SNP display results", "Homa");

#my $prefs = CXGN::Page::UserPrefs->new;
#my $vhost_conf = CXGN::VHost->new();

my $snp_id = $page->get_encoded_arguments('snp_id');


#Create a database handle 
my $dbh = CXGN::DB::Connection->new();

#Create a schema object
CXGN::Marker::SNP::Schema->can('connect')
    or BAIL_OUT('Could not load the CXGN::Marker::SNP::Schema module');

my $schema = CXGN::Marker::SNP::Schema->connect(sub{$dbh->get_actual_dbh() },
                                                   {on_connect_do => ['SET search_path TO marker;']},
                                               );
my ($snp_id) = $page->get_encoded_arguments("snp_id");


my $snp = CXGN::Marker::SNP::Snp->new($schema, $snp_id);

if (!$snp->get_snp_id()) { 
    $page->message_page("The SNP with the id $snp_id is not defined. Sorry :-( ");
}

my $html = info_section_html(title    => 'SNP',
                             contents => '$snp_id',
    );


$page->header();

print page_title_html('SNP database');
print $html;
$page->footer();

 
