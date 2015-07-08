#!/usr/bin/perl/

use strict;
use warnings;

use CXGN::Page;
use CXGN::Login;
use CXGN::Apache::Error;
use CXGN::DB::Connection;
use CXGN::Page::FormattingHelpers qw /info_section_html
                                       tooltipped_text /;

use CXGN::Chado::Publication;
use CXGN::Phenome::Locus;
use CXGN::Phenome::Locus::LocusRanking;

my $page=CXGN::Page->new( "locus_pub_rank", "Naama");

my %args = $page->cgi_params(); #multi-valued parameters have values in a string, delimited by \0
my $locus_id= $args{locus_id};
my $dbh=CXGN::DB::Connection->new('phenome');

$page->jsan_use("CXGN.Phenome.Locus");
$page->jsan_use("Prototype");


my($person_id,$user_type)=CXGN::Login->new($dbh)->has_session();

my $locus=CXGN::Phenome::Locus->new($dbh,$locus_id);
my $locus_name=$locus->get_locus_name();

my @assoc_pubs= $locus->get_dbxrefs_by_type('literature');
$page->simple_header("Publication list for locus $locus_name", "Curator tool: Validate publications associated with locus <a href=locus_display.pl?locus_id=$locus_id target=blanc>$locus_name</a>");

my $locus_pub_ranks=$locus->get_locus_pub();
my $pubs="";
my ($val_pubs, $rej_pubs, $pending_pubs, $a_pubs)= ("" x 4);

my @pub;

foreach(sort  { $locus_pub_ranks->{$b} <=>  $locus_pub_ranks->{$a} } keys %$locus_pub_ranks )  {
#foreach ( keys %$locus_pub_ranks) {
    my $publication=CXGN::Chado::Publication->new($dbh, $_);
    my $pub_id = $publication->get_pub_id(); 
    my $dbxref_id = $publication->get_dbxref_id_by_db('PMID');
    my $title=$publication->get_title();
    my $pyear=$publication->get_pyear();
    my $series=$publication->get_series_name();
    my $volume=$publication->get_volume();
    my $issue=$publication->get_issue();
    my $pages=$publication->get_pages();
    my $abstract= $publication->get_abstract();
    my $authors=$publication->get_authors_as_string();
    my $locusRank = CXGN::Phenome::Locus::LocusRanking->new($dbh, $locus_id, $pub_id);
    my $validated = $locusRank->get_validate() || "";
    my $score = $locusRank->get_rank();
    
    my $val_form= "<BR><BR>";
    if ($user_type eq 'curator') {
	$val_form= qq|
	<div id='locusPubForm_$pub_id'>
	<div id='pub_dbxref_id_$dbxref_id'>
	<input type="hidden" 
	value=$dbxref_id
	id="dbxref_id_$pub_id">
	<select id="$dbxref_id"  >
	<option value="" selected></option>
	<option value="no">no</option>
	<option value="yes">yes</option>
	<option value="maybe">maybe</option>
	</select>
	<input type="button"
	id="associate_pub_button"
	value="associate publication"
	onclick="Locus.addLocusDbxref('$locus_id', '$dbxref_id');this.disabled=false;">
	</div>
	</div>
	<BR>
	|;
    }
    my $associated= $publication->is_associated_publication('locus', $locus_id);
    my $pub_link= tooltipped_text("$authors ($pyear)",$abstract) . qq| <a href="/publication/$pub_id/view">$title.</a> $series. $volume($issue):$pages <b> Match score = $score </b> | . $val_form;
    if ($validated eq 'no') {
	$rej_pubs .= $pub_link; 
    }elsif ($validated eq 'yes') {
	$val_pubs .= $pub_link;
    }elsif ($validated eq 'maybe') {
	$pending_pubs .= $pub_link;
    }elsif (!$associated) { 
	$pubs .= $pub_link;      
    }elsif ($associated) { 
	$a_pubs .=$pub_link;
	print STDERR "$associated ! pub $pub_id associated with locus $locus_id\n"; }
}


print info_section_html(title   => 'Suggested publication list',
			contents => $pubs,
			);

print info_section_html(title   => 'Associated publications',
			subtitle =>'(these publications are already linked with the locus, but were not validated by a curator)',
			contents => $a_pubs,
			);

print info_section_html(title   => 'Validated publications',
			contents => $val_pubs,
			    );
print info_section_html(title   => 'Pending publications',
			contents => $pending_pubs,
			    );
print info_section_html(title   => 'Rejected publications',
			contents => $rej_pubs,
			    );


$page->simple_footer();

print <<EOF;
<a href="javascript:window.close();">Close This Window</a>
EOF

