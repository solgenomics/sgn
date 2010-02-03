#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Tools::Identifiers qw/link_identifier/;

our ($blastq, $blast_hitq);

our $page = CXGN::Page->new( "SGN Unigene - Show All Stored BLAST Hits", "Koni");
my ($unigene_id, $unigene_length, $target_id) = $page->get_arguments("unigene_id","l", "t");

my $dbh = CXGN::DB::Connection->new();

if ($target_id =~ /^\d+$/) {
  $blastq = $dbh->prepare("SELECT blast_annotation_id, blast_targets.blast_target_id,
                                blast_program, db_name, n_hits, hits_stored
                           FROM blast_annotations
                                LEFT JOIN blast_targets USING (blast_target_id)
                           WHERE apply_id=? AND blast_targets.blast_target_id=? AND apply_type=15");
} else {
  $blastq = $dbh->prepare("SELECT blast_annotation_id, blast_targets.blast_target_id,
                                blast_program, db_name, n_hits, hits_stored
                           FROM blast_annotations
                                LEFT JOIN blast_targets USING (blast_target_id)
                           WHERE apply_id=? AND apply_type=15");
}

$blast_hitq = $dbh->prepare("SELECT blast_hits.target_db_id, evalue, score,
                                    identity_percentage, apply_start, apply_end, defline
                             FROM blast_hits
                                  LEFT JOIN blast_defline USING (defline_id)
                             WHERE blast_annotation_id=?
                             ORDER BY score DESC");

#&local_init;



if ($unigene_id eq "") {
  empty_search();
}

unless ($unigene_length > 0){
  empty_search();
}

if (int($unigene_id) ne $unigene_id) {
  invalid_search($unigene_id);
}

  my $blast_content = "";

if ($target_id =~ /^\d+$/){

  $blastq->execute($unigene_id, $target_id);
} else {
  warn "XXX querying with ONLY unigene_id";
  $blastq->execute($unigene_id);
}

  while(my ($blast_annotation_id, $blast_target_id, $blast_program,
	    $target_dbname, $n_hits, $hits_stored) = $blastq->fetchrow_array()) {
    $blast_content .= qq(<tr><td align="left"><b>$target_dbname [$blast_program]</b></td><td align="right" colspan="5"> Showing best $hits_stored hits recorded </td></tr>);

    $blast_hitq->execute($blast_annotation_id);
    while(my ($match_id,$evalue,$score,$identity,$start,$end,
	      $defline) = $blast_hitq->fetchrow_array()) {

      $match_id = link_identifier($match_id) || $match_id;

      if (length($defline)>120) {
	$defline = substr($defline, 0, 117) . "...";
      }
      my $alignment_length = abs($end - $start) + 1;

      my $span_percent = sprintf "%3.1f%%",
	($alignment_length/$unigene_length)*100.0;
      my $frame;
      # This assumes BLAST start/end coordinates are adjusted to start with
      # index 0 for the first base, as per C and perl style string addressing
      # Normally, BLAST addressing indexing the first base as 1.
      if ($start < $end) {
	$frame = ($start % 3) + 1;
      } else {
	$frame = -((($unigene_length - $start - 1) % 3) + 1);
      }

      $blast_content .= <<EOF;
      <tr><td><b>Match:</b> $match_id</td>
	  <td><b>score:</b> $score</td>
          <td><b>e-value:</b> $evalue</td>
          <td><b>Identity:</b> $identity%</td>
          <td><b>Span:</b> ${alignment_length}bp ($span_percent)</td>
	  <td><b>Frame:</b> $frame</td>
      </tr>
      <tr><td colspan="6">$defline</td></tr>
EOF
    }
    $blast_content .= qq(<tr><td colspan="6"><br /></td></tr>);
    if ($hits_stored < $n_hits) {
      my $t_hits = $n_hits - $hits_stored;
      $blast_content .= qq(<tr><td colspan="6" align="center"><font color="gray">$t_hits lower scoring hits censored --  only $hits_stored best hits are stored.</font></td></tr>);
    }
  }


  if ($blast_content eq "") {
    $blast_content = qq(<tr><td><font color="gray">No BLAST annotations were found</td></tr>);
  } else {
    $blast_content = qq(<tr><td><table cellspacing="0" border="0" width="100%" align="center">) . $blast_content ."</table></td></tr>";
  }



$page->header();

print <<EOF;
<table cellpadding="0" cellspacing="0" border="0" width="100%" align="center">
<tr><td align="center"><b>All Stored BLAST annotations for SGN-U$unigene_id</b></td></tr>
$blast_content
<tr><td><br /></td></tr>
</table>

EOF

$page->footer();

sub empty_search {

  $page->header();

  print <<EOF;
  <br />
  <b>Not enough unigene search criteria specified</b>

EOF

  $page->footer();

  exit 0;
}

sub invalid_search {
  my ($unigene_id) = @_;

  $page->header();

  print <<EOF;
  <br />
  <b>The specified unigene identifer ($unigene_id) does not result in a valid search.</b>

EOF

  $page->footer();
  exit 0;

}


sub local_init {


}
