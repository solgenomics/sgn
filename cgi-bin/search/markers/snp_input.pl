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

# Start a new SGN page.
our $page=CXGN::Page->new("SGN SNP input","Homa");
my $snp_id = $page->get_encoded_arguments('snp_id');


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


#my $unigene_position = $snp->get_unigene_position();
#my $snpid = $snp->get_snp_id();
#print $page->message_page("The serach result is $search_result:SNP_ID = $snpid, Unigene Pos: $unigene_position");





my $snp_html = info_table_html('SNP ID' => '<input type="text" size="10" value="1" name="expect" />',
' ' => '<div style="text-align: right"><input type="reset" value="Clear" /> <input type="submit" name="search" value="Search" /></div>',);
my $text_message = blue_section_html('Select SNP that differ between');


my $search_bar = info_table_html( ' ' => '<div style="text-align: right"><input type="reset" value="Clear" /> <input type="submit" name="search" value="Search" /></div>',);


my $two_snp_bars = info_table_html(
		             'Right SNP ID' => simple_selectbox_html( name => 'snp_id',
								    choices => [ [ 'choice1', 'choice1 (default)' ],
										 [ 'choice2', 'choice2 (any thing)' ],
										 [ 'choice3', 'choice3 (any thing)' ],
										 'choice4',
										 'choice5',
									       ],
								  ),
		   
		   ' ' => '<div style="text-align: right"><input type="reset" value="Clear" /> <input type="submit" name="search" value="Search" /></div>',
		             'Left SNP ID' => simple_selectbox_html( name => 'snp_id',
							      choices => [ [ 'choice1', 'all' ],
									   'none',
									   [ 'bioperl_only', 'alignment summary only' ],
									   [ 'histogram_only', 'conservedness histogram only' ],
									 ],
							           ),
		    __multicol => 2,
		    __border => 0,
		    __tableattrs => 'width="100%"', );






$page->header();

print page_title_html('SNP Database Search Results');
print $html;
print $snp_html;
print $text_message;
print $two_snp_bars;

$page->footer();

