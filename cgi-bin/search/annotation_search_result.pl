use strict;
use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Tools::Text qw/to_tsquery_string/;

# $Id$
# $Author$
# $Date$
# $Name:  $
#

my $highlight_colour='#0000FF';
my $desc_colour='#EEEEEE';
my $nr_to_show=20;
my $pagination_offset=5;
my $unig_display_nr=10;
my $search_type_print='';
my $unig_link='/search/unigene.pl';
my $show_all_unig_link='/search/all_unig_for_annot.pl';
my $clone_link='/search/est.pl?request_type=8&amp;request_from=1&amp;request_id=';

our $page = CXGN::Page->new( "Annotation Search Results", "Dan, mod by Rob");
my $dbh = CXGN::DB::Connection->new;
my $pg_version = $dbh->dbh_param("pg_server_version");
my $pg_ts_rank = $pg_version >= 80300 ? 'ts_rank' : 'rank';

#get all the relevant info for performing the search
my ($search_type,
    $search_text,
    $results_page,
    $total_matches,
    $typed_page)    =   $page->get_encoded_arguments("search_type",
						     "search_text",
						     "results_page",
						     "total_matches",
						     "typed_page");

my $tsquery_text = to_tsquery_string($search_text);

unless ($search_text) {
  null_request();
}

#if no current results page is specified, set it to 0 (first page)
$results_page ||= 0;

#if the user typed in a user-friendly page number, convert to proper page number
if($typed_page eq 'yes'){
    $results_page--;
}

my $match_count_q;
#set query type and specify proper result count sql
if ( $search_type eq 'manual_search' ){
    $search_type_print = "manual annotation";
    $match_count_q = $dbh->prepare_cached(<<EOSQL);
SELECT COUNT(*)
FROM manual_annotations
WHERE annotation_text_fulltext @@ to_tsquery(?)
EOSQL
}
elsif( $search_type eq 'blast_search' ){
    $search_type_print = "BLAST based annotation";
    $match_count_q = $dbh->prepare_cached(<<EOSQL);
SELECT COUNT(*)
FROM blast_defline
WHERE defline_fulltext @@ to_tsquery(?)
EOSQL
}
else{
    null_request();
}


#do this only if we don't know the total number of matches.  This should happen only once, on the first page
unless ($total_matches){
    $match_count_q->execute($tsquery_text);
    ($total_matches) = $match_count_q->fetchrow_array();
}


my $nr_show_to_print='';

my $start_at=$results_page * $nr_to_show;
my $end_at=$start_at + $nr_to_show;
my $nr_to_get = $end_at-$start_at;

# warn "offsets are ($start_at,$end_at,$nr_to_get,$total_matches)";
# #bound checks
# if(($start_at > $total_matches) or ($start_at < 0)){
#     $start_at = 0;
#     $nr_to_get= -1;
# }
# if($end_at > $total_matches){
#     $end_at = -1;
#     $nr_to_get= -1;
# }
# warn "offsets are ($start_at,$end_at,$nr_to_get,$total_matches)";

#execute the necessary SQL commands to get data
#do only search types requested
my @matches=();
my %unigene_list=();

if ($search_type eq 'manual_search'){

#get the text search matches

# #create temp table to store just the matches for this page
#     $manual_annot_tmp_create_q->execute();
#     $manual_annot_tmp_fill_q->bind_param(3,$start_at,SQL_INTEGER);
#     $manual_annot_tmp_fill_q->bind_param(4,$nr_to_get,SQL_INTEGER);
#     $manual_annot_tmp_fill_q->execute($search_text, $search_text, $nr_to_get,$start_at) or $page->error_page("Couldn't create temp table with search $earch_text and limit $nr_to_get offset $start_at ($DBI::errstr)\n");

# #read the details of the annotation

# #data returned by $manual_annot_matches_q is:
# #tmp.manual_annotations_id,  t.type_description, ma.annotation_text, a.author_name, ma.last_modified, tmp.score

#     $manual_annot_matches_q->execute()
#       or $page->error_page("Couldn't get manual matches ($DBI::errstr)\n");


#  $dbh->trace(2,'/tmp/dbitrace');
  my $manual_annot_matches_q = $dbh->prepare_cached(<<EOSQL);
SELECT	ma.manual_annotations_id,
	t.type_description,
	ma.annotation_text,
	a.first_name || ' ' || a.last_name,
	ma.last_modified,	
        $pg_ts_rank(annotation_text_fulltext,to_tsquery(?::text)) as score
FROM manual_annotations as ma
LEFT JOIN sgn_people.sp_person AS a
  ON (ma.author_id=a.sp_person_id)
JOIN annotation_target_type AS t
  ON (ma.annotation_target_type_id=t.annotation_target_type_id)
WHERE annotation_text_fulltext @@ to_tsquery(?::text)
      AND ma.annotation_target_type_id=1
ORDER BY score DESC
LIMIT ? OFFSET ?
EOSQL

  $manual_annot_matches_q->execute($tsquery_text,$tsquery_text,$nr_to_get,$start_at);

  if ($manual_annot_matches_q->rows == 0) {
    no_matches($search_text);
  }

  while (my ($annot_id, $type_desc, $annot_text, $author_name, $last_updated, $score) = $manual_annot_matches_q->fetchrow_array()) {

    my $annot_target_desc = "$type_desc by $author_name on $last_updated";

    push @matches, [$annot_id, $annot_target_desc, $score, $annot_text];
  }

  #get the unigene links

  my $manual_clone_unig_link_q = $dbh->prepare_cached(<<EOSQL);
SELECT	c.clone_id,
	c.clone_name,
	u.unigene_id,
	g.comment,
	ub.build_nr,
	ub.build_date,
	ub.unigene_build_id
FROM manual_annotations as ma
JOIN clone as c
  ON (ma.annotation_target_id=c.clone_id)
JOIN seqread as s
  USING (clone_id)
JOIN est
  USING (read_id)
LEFT JOIN unigene_member
  USING (est_id)
LEFT JOIN unigene as u
  USING (unigene_id)
LEFT JOIN unigene_build as ub
  USING (unigene_build_id)
LEFT JOIN groups as g
  ON (ub.organism_group_id=g.group_id)
WHERE ma.manual_annotations_id = ?
  AND (u.unigene_id IS NULL
       OR ub.status='C')
EOSQL

  foreach my $annot_id (map {$$_[0]} @matches) {
    $manual_clone_unig_link_q->execute($annot_id)
      or $page->error_page("Couldn't run manual_clone_unig_link_q ($DBI::errstr)\n");

    while (my ($clone_id, $clone_name, $unig_id, $build_desc, $build_nr, $build_date, $unig_build_id) = $manual_clone_unig_link_q->fetchrow_array()) {
      my ($unig_desc, $sort_field)=('','');
      if ($unig_id) {
	$unig_desc = "<tr><td></td><td align=\"left\" nowrap=\"nowrap\"><a href=\"$unig_link?unigene_id=$unig_id\">Unigene $unig_id</a></td>"
	             . "<td align=\"left\" nowrap=\"nowrap\">$build_desc build $build_nr from $build_date</td><td></td></tr>";
	$sort_field=$unig_build_id;
      } else {
	$unig_desc="<tr><td></td><td align=\"left\" colspan=\"3\">The annotation is associated with clone <a href=\"$clone_link$clone_id\">$clone_name</a>, which has been censored from the current unigene builds.</td></tr>";
	$sort_field=$clone_id;
      }


      push @{$unigene_list{$annot_id}}, [$unig_desc, $sort_field];
	
    }
  }

} elsif ($search_type eq 'blast_search'){

    my $blast_matches_q = $dbh->prepare_cached(<<EOSQL);
SELECT	defline_id,
	bt.db_name,
	defline,
	bt.blast_program,
	$pg_ts_rank(defline_fulltext,to_tsquery(?)) as score
FROM blast_defline
JOIN blast_targets as bt
  USING (blast_target_id)
WHERE defline_fulltext @@ to_tsquery(?)
ORDER BY score DESC
LIMIT ? OFFSET ?
EOSQL

    $blast_matches_q->execute($tsquery_text,$tsquery_text,$nr_to_get,$start_at)
      or $page->error_page("Couldn't get blast matches ($DBI::errstr)\n");


    if ($blast_matches_q->rows == 0){
#clean up the temp table voodoo
#	eval{ $blast_tmp_drop_q->execute() };
#	  or $page->error_page("Couldn't drop temp table ($DBI::errstr)\n");
	no_matches($search_text);
    }

    while(my ($defline_id, $blast_target_db, $defline, $blast_program,  $score) = $blast_matches_q->fetchrow_array()) {
	my $annot_target_desc = "Unigene <b>$blast_program</b> search against <b>$blast_target_db</b>";
	push @matches, [$defline_id, $annot_target_desc, $score, $defline];
    }


    my $blast_unig_link_q = $dbh->prepare_cached(<<EOSQL);
SELECT	u.unigene_id,
	g.comment,
	bh.score,
	bh.evalue,
	bh.identity_percentage,
	bh.apply_start,
	bh.apply_end
FROM blast_defline as bd
JOIN blast_hits as bh
  USING(defline_id)
JOIN blast_annotations as ba
  USING(blast_annotation_id)
JOIN unigene as u
  ON (ba.apply_id=u.unigene_id)
JOIN unigene_build as ub
  USING (unigene_build_id)
JOIN groups as g
  ON (ub.organism_group_id=g.group_id)
WHERE bd.defline_id = ?
AND ba.apply_type=15 and ub.status='C'
ORDER BY g.comment, u.unigene_id
EOSQL

    foreach my $defline_id (map {$$_[0]} @matches) {
      $blast_unig_link_q->execute($defline_id);
      while( my ( $unig_id,
		  $build_desc,
		  $blast_score,
		  $evalue,
		  $identity_pct,
		  $span_start,
		  $span_end     )  = $blast_unig_link_q->fetchrow_array()
	   ) {
	my $span_ln=abs($span_end - $span_start);
	$identity_pct=sprintf "%7.2f", $identity_pct;
	my $unig_desc=<<EOH;
<tr>
  <td></td>
  <td align="left" style="white-space: nowrap"><a href="$unig_link?unigene_id=$unig_id">Unigene $unig_id</a></td>
  <td align="left" style="white-space: nowrap">$build_desc;</td>
  <td align="left" style="white-space: nowrap"> matched with $identity_pct% identity over ${span_ln}bp (e-value $evalue)</td>
</tr>
EOH
	push @{$unigene_list{$defline_id}}, [$unig_desc, $blast_score];
      }
    }
}

#set up all the page navigation stuff

my $nr_pages = int (($total_matches - 1)/$nr_to_show) + 1;

my $prev_page=$results_page - 1;
my $next_page=$results_page + 1;
my $pagination_print='';


unless($nr_pages == 1){

    my $pagination_start=$results_page-$pagination_offset;
    my $pagination_end=$results_page+$pagination_offset;
    my ($start_skip, $end_skip) = (1,1);
    my $last_page=$nr_pages-1;
    my $pagination_range= 2*$pagination_offset +1;

    if($pagination_start < 0){
	$pagination_start = 0;
	$pagination_end = $pagination_start + $pagination_range;
	if($pagination_end > $nr_pages){
	    $pagination_end = $nr_pages;
	}
	$start_skip=0;
    }
    if($pagination_end >= $nr_pages){
	$pagination_end = $nr_pages;
	$pagination_start = $pagination_end - $pagination_range;
	if($pagination_start < 0){
	    $pagination_start = 0;
	}
	$end_skip=0;
    }

    $pagination_print.="<tr><td colspan=\"2\" align=\"center\" bgcolor=\"#EEEEEE\">";

    if ($prev_page >= 0){
	$pagination_print .= "<a href=\"annotation_search_result.pl?search_text=$search_text&amp;request_from=1&amp;search_type=$search_type&amp;results_page=$prev_page\">&lt; Previous</a> |";
	$start_skip and $pagination_print .= "| ... |";
    }
    else{
	$pagination_print .= "|";
    }

    my $pg_nr;
    for($pg_nr=$pagination_start; $pg_nr<$pagination_end; $pg_nr++){
	my $pg_nr_to_display=$pg_nr+1;
	if ($pg_nr == $results_page){
	    $pagination_print.="| <b>$pg_nr_to_display</b> |";
	}
	else{
	    $pagination_print.="| <a href=\"annotation_search_result.pl?search_text=$search_text&amp;request_from=1&amp;search_type=$search_type&amp;results_page=$pg_nr\">$pg_nr_to_display</a> |";
	}
    }

    if ($next_page < $nr_pages){
	
	$end_skip and $pagination_print .= "| ... |";
	$pagination_print.= "| <a href=\"annotation_search_result.pl?search_text=$search_text&amp;request_from=1&amp;search_type=$search_type&amp;results_page=$next_page\">Next &gt;</a>";
    }
    else{
	$pagination_print .= "|";
    }

    $pagination_print .= "</td></tr>";

    if($nr_pages > $pagination_range){
      $pagination_print .= <<EOH;
<tr><td colspan="2" align="center" bgcolor="#EEEEEE">
  <table align="center" cellspacing="0" cellpadding="0" border="0">
  <tr><td align="left" style="white-space: nowrap"><a href="annotation_search_result.pl?search_text=$search_text&amp;request_from=1&amp;search_type=$search_type&amp;results_page=0">&lt; First Page</a> || Page [1-$nr_pages]</td>
  <td align="center" style="white-space: nowrap">
  <form method="get" action="/search/annotation_search_result.pl">
  <input type="hidden" name="search_text" value="$search_text" />
  <input type="hidden" name="typed_page" value="yes" />
  <input type="hidden" name="request_from" value="1" />
  <input type="hidden" name="search_type" value="$search_type" />
  <input type="text" name="results_page" style="background: #EEEEFF" size="4" />
  <input name="get_page" type="submit" value="go" />
  </form>
  </td><td align="right" style="white-space: nowrap">
  &nbsp;||&nbsp;<a href="annotation_search_result.pl?search_text=$search_text&amp;request_from=1&amp;search_type=$search_type&amp;results_page=$last_page">Last Page &gt;</a>
  </td></tr>
  </table>

</td></tr>
EOH
    }
}


#beautify for screen
if ($total_matches <= $nr_to_show){
    $nr_show_to_print="Showing <b>all</b> matches";
}
elsif ($end_at < 0){
    $nr_show_to_print = "Showing last <b>" . ($total_matches - $start_at) . "</b> matches";
}
else {
    $nr_show_to_print= "Showing matches <b>" .($start_at + 1) ."</b> to <b>" . ($end_at) . "</b>";
}


#get the data ready for display

my @results=();

#match data is:
#[match_id, annotated_data_description, text_search_match_score, annotation_text];

foreach my $match (@matches){

    my $match_text=$$match[3];
    my $score = sprintf "%7.2f", $$match[2];
    my $annot_link_id=$$match[0];
    my @unigene_info;

    if ($unigene_list{$annot_link_id}){
	@unigene_info=@{$unigene_list{$annot_link_id}};
    }

#strip <br /> tags.
#this is for the current specific version of manual annotation
#it is a kludge, there should be a text only searchable field
# and a separate html enhanced text display field in the db

    $match_text =~ s/\<br\>/  /g;

#insert <br /> in front of genbank id tags to break up long deflines
    $match_text =~ s/(gi\|)/<br \/>$1/g;

#highlight matches

    my @word_parts=split /\W/, $search_text;
     foreach (@word_parts){
	$_ or next;
	$match_text =~ s/($_)/\<span class="hilite"\>$1\<\/span\>/ig;
    }
    my $web_format="
	<tr><td bgcolor=\"$desc_colour\">$$match[1]</td>
	<td align=\"right\" bgcolor=\"$desc_colour\">Text Match Relevance: $score</td></tr>
        <tr><td colspan=\"2\">$match_text</td></tr>";

    if (@unigene_info){
	$web_format .= <<EOH;
<tr><td colspan="2" align="left" nowrap="nowrap"><br />Unigenes containing this annotation:</td></tr>
<tr><td colspan="2" align="left" nowrap="nowrap">
<table align="left" cellspacing="2" cellpadding="0" border="0">
EOH


#unigene data is:
#[unigene_line, sorting_value]
# the unigene line has 4 columns

	my $display_count=0;
	my $nr_unigenes=@unigene_info;
	foreach (sort{$$b[1] <=> $$a[1]} @unigene_info){

#show only a set nr of matches, add link to "Show More" if exceeded
	    if($display_count >= $unig_display_nr){
		$web_format .= <<EOH;
                <tr><td></td><td colspan="3">...</td></tr>
                <tr><td></td><td colspan="3"></td></tr>
                <tr><td></td><td align="left" colspan="3" style="white-space: nowrap">
                Showing only top $unig_display_nr of $nr_unigenes.&nbsp;
                [<a href="$show_all_unig_link?match_id=$annot_link_id&amp;search_type=$search_type" target="All_Unigenes">Show All</a>]
                </td></tr>
EOH
		last;
	    }

	    $web_format .= "$$_[0]";
	    $display_count++;
	}
	$web_format .="</table></td></tr>";	
    }
    else{
	$web_format .= qq|<tr><td colspan="2" align="left" style="white-space: nowrap"><br />No unigenes contain this annotation</td></tr>|
	}

    $web_format .= qq|<tr><td colspan="2">&nbsp;</td></tr>|;
    push @results, $web_format;
}


#start printing the page
$page->header();

print<<EOF
    <table align="center" cellspacing="0" cellpadding="2" border="0" width="100%">
    <tr><td colspan="2" align="center" bgcolor="#EEEEEE">Your search for <b>$search_text</b> in <b>$search_type_print</b> returned <b>$total_matches</b> results</td></tr>
    <tr><td colspan="2" align="center" bgcolor="#EEEEEE">$nr_show_to_print</td></tr>
    $pagination_print
    <tr><td colspan="2" bgcolor="#FFFFFF"><br /></td></tr>
@results
    <tr><td colspan="2" bgcolor="#FFFFFF"><br /></td></tr>
    $pagination_print
</table>
EOF
;

$page->footer();





sub no_matches {
  my ($search_text) = @_;

  $page->header();

  print <<EOF;

  <p>Your search for <b>$search_text</b> did not find any relevant matches in our database.<br /><br />
<b>Note:</b> Keywords of less than 4 letters or those that occur in more than half the data are ignored by the search.
<br /><br />
EOF

  $page->footer();

  exit 0;
}


sub null_request {

  $page->header();

  print <<EOF;

  <p><b>Please enter a search word or phrase and select the annotation type you want to search.</b>

EOF

  $page->footer();

  exit 0;
}


