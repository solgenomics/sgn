#!/usr/bin/perl

use CXGN::Page;
use CXGN::VHost;
use File::Spec;
use CXGN::DB::Connection;
use CXGN::BlastWatch;
use strict;

our $page = CXGN::Page->new( "BLAST watch results", "Adri");

# get arguments
my $r = Apache2::RequestUtil->request;
$r->content_type("text/html");
my $req = Apache2::Request->new($r);

my $bw_query_id;

if ($r->method eq 'POST') {
    $bw_query_id = $req->body("query");
}
else {
    my $args = $r->args;
    $args =~ /query=(\d+)/;
    $bw_query_id = $1;
}

my $dbh = CXGN::DB::Connection->new();

if (!$bw_query_id) {&user_error("No query chosen.") }

my $select = "SELECT sequence, program, database, matrix, evalue, num_results "
    . "FROM blastwatch_queries where blastwatch_queries_id = ?";
my $sth = $dbh->prepare($select);
$sth->execute($bw_query_id);
my (@v) = $sth->fetchrow();
$sth->finish;

my $results = CXGN::BlastWatch::get_results($dbh,$bw_query_id);

if (!$results) { &user_error("Invalid query.") }

&website($results,@v);

#---------------#

sub website {

    my ($results,$sequence,$program,$database,$matrix,$evalue,$num_results) = @_;

    # force sequence to wrap                                                                                                                         
    
    my $length = length($sequence);
    my $wrap = 85;
    for (my $i = $wrap; $i < $length ; $i += $wrap + 1) {
	substr($sequence, $i, 0) = " ";
    }
    
    $page->header('BLAST Watch Results','BLAST Watch Results');
    
    print <<EOF;

<p><strong>Query sequence:</strong><br/>
$sequence</p>

<p><strong>Program:</strong> $program</p>

<p><strong>Database:</strong> $database</p>

<p><strong>Substitution Matrix:</strong> $matrix</p>

<p><strong>Expect (e-value) Threshold:</strong> $evalue</p>

<strong>Results:</strong>

EOF

if ($results ne "No results found.") {
    print <<TEXT;
    
    <table summary="" width="90%">
	<td><strong>Query</strong></td>
	<td><strong>Hit</strong></td>
	<td><strong>Start</strong></td>
	<td><strong>End</strong></td>
	<td><strong>E-value</strong></td>
	<td><strong>Score</strong></td>
	<td></td>
	</tr>
	$results
	</table>
	
TEXT
}

    else { print $results }

    $page->footer();
    
}

sub user_error {

    my $reason = shift;
    
    $page->header();
    
    print <<EOF;
    <h4>SGN BLAST Watch Error</h4>
	<p>$reason</p>
EOF

    $page->footer();
    exit(0);
}
