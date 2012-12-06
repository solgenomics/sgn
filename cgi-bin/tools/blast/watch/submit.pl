#!usr/bin/perl -w

use strict;
use CXGN::Page;
use File::Spec;
use CXGN::DB::Connection;
use CXGN::BlastWatch;
use CXGN::Page::FormattingHelpers qw/page_title_html modesel info_table_html hierarchical_selectboxes_html simple_selectbox_html/;

my $page = CXGN::Page->new( "BLAST watch submission", "Adri");

# get arguments from index.pl
use CatalystX::GlobalContext qw( $c );
post_only() unless $c->req->method eq 'POST';

my $params = $c->req->params;

# dehash, because it's easier later..
my $database = $params->{database};
my $program = $params->{program};
my $matrix = $params->{matrix};

# check evalue
my $evalue = $params->{evalue};
if (!$evalue) {
    user_error($page, "Please enter a valid expect value.\n");
}
elsif ($evalue !~ m/(e\-[0-9]+|[0-9]+e\-[0-9]+|[0-9]+\.[0-9]+)/ or $evalue <= 0.0) {
    user_error($page, "Invalid Expect value \"$evalue\". Please enter a valid expect value.\n");
}

# check sequence
my $sequence = $params->{sequence};
if (!$sequence or $sequence eq "") {
    user_error($page,"You must specify a sequence in FASTA format to perform a BLAST search");
}

if ($sequence =~ />.+>/ ) { }

my $seq_count = ($sequence =~ tr/>//);
if($seq_count > 1) {
    &user_error($page,"Please submit only one query sequence at a time.");
}

if ($sequence !~ m/\s*>/) {
    $sequence = ">WEB-USER-SEQUENCE (Unknown)\n$sequence";
}

my $sp_person_id = $params->{sp_person_id};
if (!$sp_person_id) {
    user_error($page,"Please login first.");
}

my $dbh = CXGN::DB::Connection->new();

unless (my $flag = CXGN::BlastWatch::insert_query($dbh, $sp_person_id, $sequence, $program, $database, $matrix, $evalue)) {
    user_error($page,"You have already submitted this query!");
}

$dbh->disconnect(42);

website($page);

#### ------------------------- ####

sub website {
    my ($page) = @_;
    $page->header();
    print page_title_html('Success!');

    print <<EOF;
    <p>Your query has been added to SGN BLAST Watch.  You will receive an email when there are new results.</p>
EOF
	
    $page->footer();
    
}

sub post_only {
    my ($page) = @_;
    
    $page->header();
    print page_title_html('SGN BLAST Watch Interface Error');
    
    print <<EOF;
    <p>BLAST subsystem can only accept HTTP POST requests</p>
EOF
	
    $page->footer();
    exit(0);
}


sub user_error {
    my ($page,$reason) = @_;
    
    $page->header();
    print page_title_html('SGN BLAST Watch Error');

    print <<EOF;
    <p>$reason</p>
EOF

    $page->footer();
    exit(0);
}
