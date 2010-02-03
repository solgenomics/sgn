#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::DB::Connection;

our %builds;
our $page = CXGN::Page->new( "SGN Unigene Build Summary", "Koni");

my $dbh = CXGN::DB::Connection->new();
my $buildq = $dbh->prepare("SELECT unigene_build_id, groups.comment, build_date from unigene_build LEFT JOIN groups ON (groups.group_id=unigene_build.organism_group_id) where status=?");
my $clusterq = $dbh->prepare("SELECT COUNT(DISTINCT cluster_no) from unigene where unigene_build_id=?");
my $contigq = $dbh->prepare("SELECT COUNT(unigene_id) from unigene where nr_members>1 and unigene_build_id=?");
my $singletq = $dbh->prepare("SELECT COUNT(unigene_id) from unigene where nr_members=1 and unigene_build_id=?");
my $source_dataq = $dbh->prepare("SELECT COUNT(group_id) from unigene_build LEFT JOIN group_linkage ON (unigene_build.source_data_group_id=group_linkage.group_id) where unigene_build_id=?");
$buildq->execute("C");
while(my ($build_id, $build_name, $build_date) = $buildq->fetchrow_array()) 
{

    $builds{$build_name}->{build_date} = $build_date;

    $clusterq->execute($build_id);
    ($builds{$build_name}->{clusters}) = $clusterq->fetchrow_array();
    $contigq->execute($build_id);
    ($builds{$build_name}->{contigs}) = $contigq->fetchrow_array();
    $singletq->execute($build_id);
    ($builds{$build_name}->{singlets}) = $singletq->fetchrow_array();
    $source_dataq->execute($build_id);
    ($builds{$build_name}->{nr_inputs}) = $source_dataq->fetchrow_array();

    $builds{$build_name}->{unigenes} = $builds{$build_name}->{singlets} + $builds{$build_name}->{contigs};

}
$buildq->finish();
$clusterq->finish();
$contigq->finish();
$singletq->finish();
$source_dataq->finish();

$page->header();

print <<EOF;

<h3>Unigene Build Statistics</h3>
Summary of all current unigene builds available on SGN. Unigene builds are updated periodically as new data becomes available or new advances are made in assembly technology or strategy. For information on each build series, click the links below.

<font color="gray">Note: Content describing each build series is under development as each build series is updated with our latest assembly strategy. Links will be added as each build is updated.</font>

<table summary="" cellspacing="0" cellpadding="0" border="0" align="center" width="60%">

EOF

foreach my $build_name ( sort { $builds{$b}->{build_date} cmp $builds{$a}->{build_date} } keys %builds ) {

  print <<EOF;
  <tr><td colspan="2"><b>$build_name</b></td><td>Date: $builds{$build_name}->{build_date}</td></tr>
  <tr><td colspan="3">$builds{$build_name}->{nr_inputs} ESTs assembled into $builds{$build_name}->{unigenes} unigenes</td></tr>
  <tr><td>Clusters: $builds{$build_name}->{clusters}</td>
      <td>Contigs: $builds{$build_name}->{contigs}</td>
      <td>Singlets: $builds{$build_name}->{singlets}</td></tr>
  <tr><td colspan="3"><br /></td></tr>

EOF
}

print "</table><br /><br />";

$page->footer();
