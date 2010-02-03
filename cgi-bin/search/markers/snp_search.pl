use strict;
use CXGN::Marker::SNP::Snp;
use CXGN::Marker::SNP::Schema;
use CXGN::DB::Connection;
use CXGN::VHost;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html
                                     info_section_html
				     page_title_html
				     columnar_table_html
                                     info_table_html
                                     modesel 
                                     info_table_html
                                     hierarchical_selectboxes_html 
                                     simple_selectbox_html
    /;
our $page = CXGn::page->new("SGN SNP Search, Homa");

#creat a new dtabase handle
my $dbh = CXGN::DB::Connection->new();

#Creat a schema object
CXGN::Marker::SNP::Schema->can('connect')
    or BAIL_OUT('Could not load the CXGN::Marker::SNP::Schema module');

my $schema = CXGN::Marker::SNP::Schema->connect(sub{$dbh->get_actual_dbh()},
                                                   {on_connect_do => ['SET search_path TO marker;']},
    );


my ($snp_id) = $page->get_encoded_arguments("snp_id");

my $snp = CXGN::Marker::SNP::Snp->new($schema, $snp_id);

if (!$snp->get_snp_id()){
    $page->message_page("The SNP with the id $snp_id is undefind");
}

my $html = info_section_html(title     => 'SNP',
                             contents  => '$snp_id',
    );

#create search object
my $search_result = $snp->get_resultset('Snp')->search({snp_id => $snp_id}); 

if(!defined($search_result)){
    $page->message_page("The SNP with $snp_id could not be found");

}










$page->header();

print page_title_html('SNP Database Search Results');
print $html;
print $snp_html;
print $text_message;
print $two_snp_bars;


$page->footer();

