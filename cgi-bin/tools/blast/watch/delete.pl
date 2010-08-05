#!usr/bin/perl
use strict;
use warnings;

use CXGN::Page;
use CXGN::BlastWatch;
use CXGN::DB::Connection;
use CXGN::Page::FormattingHelpers qw/page_title_html modesel info_table_html hierarchical_selectboxes_html simple_selectbox_html/;

my $page = CXGN::Page->new("", "Adri");
use CatalystX::GlobalContext qw( $c );

# get query_id and person_id from toplevel.pl

&post_only unless $c->req->method eq 'POST';

my $params = $c->req->params;

my @bw_query_ids = $params->{'bw_query_id'};

my $sp_person_id = $params->{'sp_person_id'};

my $dbh = CXGN::DB::Connection->new("public");

my $deleted = CXGN::BlastWatch::delete_query($dbh,$sp_person_id,@bw_query_ids);

unless ($deleted) { &user_error("ERROR: Sequence does not exist or you do not have permission to remove it.") }

$dbh->disconnect(42);

&website;

sub post_only {
    $c->throw( message => 'BLAST subsystem can only accept HTTP POST requests',
               is_error => 0 );
}

sub website {
    $page->header();
    print page_title_html('Success!');
    
    print <<EOF;
    <p>Your query has been removed from SGN BLAST Watch.</p>
EOF
	
    $page->footer(); 
}

sub user_error {

    my $reason = shift;
    
    $page->header();
    print page_title_html('SGN BLAST Watch Error');

    print <<EOF;
    <p>$reason</p>
EOF

    $page->footer();
    exit(0);
}

