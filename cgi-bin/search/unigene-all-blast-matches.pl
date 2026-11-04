#!/usr/bin/perl -w
use strict;
use CatalystX::GlobalContext '$c';
use SGN::I18N;
use HTML::Entities qw(encode_entities);
my SGN::I18N $i18n = eval { $c && $c->i18n };
my $blast_ui_match = encode_entities(($i18n ? $i18n->p("global.est.match", "Match:") : "Match:"));
my $blast_ui_score = encode_entities(($i18n ? $i18n->p("global.final_caption.score", "score:") : "score:"));
my $blast_ui_identity = encode_entities(($i18n ? $i18n->p("global.final_caption.identity", "Identity:") : "Identity:"));
my $blast_ui_span = encode_entities(($i18n ? $i18n->p("global.final_caption.span", "Span:") : "Span:"));
my $blast_ui_frame = encode_entities(($i18n ? $i18n->p("global.final_caption.frame", "Frame:") : "Frame:"));
use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Tools::Identifiers qw/link_identifier/;

our ($blastq, $blast_hitq);

our $page = CXGN::Page->new( encode_entities(($i18n ? $i18n->p("global.final_caption.sgn_unigene_show_all_stored_blast_hits", "SGN Unigene - Show All Stored BLAST Hits") : "SGN Unigene - Show All Stored BLAST Hits")), "Koni");
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
    my $showing_hits = encode_entities(($i18n ? $i18n->p("global.final_caption.blast_showing", "Showing best %{count} hits recorded", {count => $hits_stored}) : "Showing best $hits_stored hits recorded"));
    $blast_content .= qq(<tr><td align="left"><b>$target_dbname [$blast_program]</b></td><td align="right" colspan="5"> $showing_hits </td></tr>);

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
      <tr><td><b>$blast_ui_match</b> $match_id</td>
	  <td><b>$blast_ui_score</b> $score</td>
          <td><b>e-value:</b> $evalue</td>
          <td><b>$blast_ui_identity</b> $identity%</td>
          <td><b>$blast_ui_span</b> ${alignment_length}bp ($span_percent)</td>
	  <td><b>$blast_ui_frame</b> $frame</td>
      </tr>
      <tr><td colspan="6">$defline</td></tr>
EOF
    }
    $blast_content .= qq(<tr><td colspan="6"><br /></td></tr>);
    if ($hits_stored < $n_hits) {
      my $t_hits = $n_hits - $hits_stored;
      my $censored_hits = encode_entities(($i18n ? $i18n->p("global.final_caption.blast_censored", "%{censored} lower scoring hits censored --  only %{stored} best hits are stored.", {censored => $t_hits, stored => $hits_stored}) : "$t_hits lower scoring hits censored --  only $hits_stored best hits are stored."));
      $blast_content .= qq(<tr><td colspan="6" align="center"><font color="gray">$censored_hits</font></td></tr>);
    }
  }


  if ($blast_content eq "") {
    $blast_content = qq(<tr><td><font color="gray">) . encode_entities(($i18n ? $i18n->p('global.unigene-all-blast-matches.no_annotations', 'No BLAST annotations were found') : 'No BLAST annotations were found')) . qq(</td></tr>);
  } else {
    $blast_content = qq(<tr><td><table cellspacing="0" border="0" width="100%" align="center">) . $blast_content ."</table></td></tr>";
  }



$page->header();
my $stored_blast_title = encode_entities(($i18n ? $i18n->p("global.final_caption.blast_title", "All Stored BLAST annotations for SGN-U%{id}", {id => $unigene_id}) : "All Stored BLAST annotations for SGN-U$unigene_id"));

print <<EOF;
<table cellpadding="0" cellspacing="0" border="0" width="100%" align="center">
<tr><td align="center"><b>$stored_blast_title</b></td></tr>
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
  <b>The specified unigene identifier ($unigene_id) does not result in a valid search.</b>

EOF

  $page->footer();
  exit 0;

}


sub local_init {


}
