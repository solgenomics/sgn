#!usr/bin/perl

use strict;
use CXGN::Page;
use CXGN::BlastWatch;
use CXGN::DB::Connection;
use CXGN::Page::FormattingHelpers qw/page_title_html modesel info_table_html hierarchical_selectboxes_html simple_selectbox_html/;

our $page = CXGN::Page->new("", "Adri");

# get query_id and person_id from toplevel.pl

my $r = Apache2::RequestUtil->request;
$r->content_type("text/html");

my $req = Apache2::Request->new($r);

my $params = $r->method eq 'POST' ? $req->body : &post_only;

my @bw_query_ids;

# TODO: can currently only delete one at a time...

push (@bw_query_ids, $params->{'bw_query_id'});
my $sp_person_id = $params->{'sp_person_id'};

my $dbh = CXGN::DB::Connection->new("public");

my $deleted = CXGN::BlastWatch::delete_query($dbh,$sp_person_id,@bw_query_ids);

unless ($deleted) { &user_error("ERROR: Sequence does not exist or you do not have permission to remove it.") }

$dbh->disconnect(42);

&website;

sub post_only {
    
    $page->header();
    
    print <<EOF;
    <h4>SGN BLAST Watch Interface Error</h4>
    <p>BLAST subsystem can only accept HTTP POST requests</p>
EOF
	
    $page->footer();
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

sub post_only {
    
    $page->header();
    print page_title_html('SGN BLAST Watch Interface Error');
    
    print <<EOF;
    <p>BLAST subsystem can only accept HTTP POST requests</p>
EOF
	
    $page->footer();
    exit(0);
}
