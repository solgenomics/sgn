use strict;
use CXGN::Page;
use CXGN::DB::Connection;

my $dbh = CXGN::DB::Connection->new();

#currently, we only search annotation based on clones
#combining annotation targets creates problems for determining
#the proper join path to pull in unigene info

my $manual_annot_matches_q = $dbh->prepare("select t.type_description, ma.annotation_text, a.first_name || ' ' || a.last_name, ma.last_modified from manual_annotations as ma left join sgn_people.sp_person as a on (ma.author_id=a.sp_person_id) left join annotation_target_type as t on (ma.annotation_target_type_id=t.annotation_target_type_id) where ma.manual_annotations_id=? and ma.annotation_target_type_id='1'");

my $manual_clone_unig_link_q = $dbh->prepare("select u.unigene_id, g.comment, ub.build_nr, ub.build_date, ub.unigene_build_id from manual_annotations as ma left join seqread as s on (ma.annotation_target_id=s.clone_id) left join est using (read_id) left join unigene_member using (est_id) left join unigene as u using (unigene_id) left join unigene_build as ub using (unigene_build_id) left join groups as g on (ub.organism_group_id=g.group_id) where ub.status='C' and ma.manual_annotations_id=? and ma.annotation_target_type_id='1'");


my $blast_matches_q = $dbh->prepare ("select bt.db_name, bd.defline, bt.blast_program from blast_defline as bd left join blast_targets as bt using (blast_target_id) where bd.defline_id=?");

my $blast_unig_link_q = $dbh->prepare("select u.unigene_id, g.comment, bh.score, bh.evalue, bh.identity_percentage, bh.apply_start, bh.apply_end from blast_defline as bd left join blast_hits as bh on (bd.defline_id=bh.defline_id) left join blast_annotations as ba using (blast_annotation_id) left join unigene as u on (ba.apply_id=u.unigene_id) left join unigene_build as ub using (unigene_build_id) left join groups as g on (ub.organism_group_id=g.group_id) where apply_type='15' and ub.status='C' and bd.defline_id=?");

my $page = CXGN::Page->new( "Annotation Search Results", "Dan");

my $desc_colour='#EEEEEE';
my $unig_link='/search/unigene.pl?unigene_id=';


#get all the relevant info for performing the search
my ($search_type, $match_id) = $page->get_arguments("search_type", "match_id");

unless ($match_id) {
  null_request();
}


#execute the necessary SQL commands to get data
#do only search types requested
my @match_detail;
my @unigene_list;

if ($search_type eq 'manual_search'){

#get the text search match

#data returned by $manual_annot_matches_q is:
#t.type_description, ma.annotation_text, a.author_name, ma.last_modified

    $manual_annot_matches_q->execute($match_id) or $page->error_page("Couldn't get manual match info\n");

   if ($manual_annot_matches_q->rows == 0) {
	no_matches($match_id);
    }

    if ($manual_annot_matches_q->rows > 1) {
	too_many_matches($match_id);
    }

    my ($type_desc, $annot_text, $author_name, $last_updated) = $manual_annot_matches_q->fetchrow_array();

    my $annot_target_desc = "$type_desc by $author_name on $last_updated";
    @match_detail = ($annot_target_desc, $annot_text);


#get the unigene links

#data returned by $manual_clone_unig_link_q is:
#u.unigene_id, g.comment, ub.build_nr, ub.build_date, ub.unigene_build_id

    $manual_clone_unig_link_q->execute($match_id) or $page->error_page("Couldn't run manual_clone_unig_link_q\n");

    while (my ($unig_id, $build_desc, $build_nr, $build_date, $unig_build_id) = $manual_clone_unig_link_q->fetchrow_array()){

	my $unig_desc="<tr><td></td><td align=\"left\" nowrap=\"nowrap\"><a href=\"$unig_link$unig_id\">SGN-U$unig_id</a></td><td align=\"left\" nowrap=\"nowrap\">$build_desc build $build_nr from $build_date</td><td></td></tr>";

	push @unigene_list, [$unig_desc, $unig_build_id];

    }

}


elsif($search_type eq 'blast_search'){


#data returned by $blast_matches_q is:
#bt.db_name, bd.defline, bt.blast_program

    $blast_matches_q->execute($match_id) or $page->error_page("Couldn't get blast matches\n");

    if ($blast_matches_q->rows == 0){
	no_matches($match_id);
    }

    if ($blast_matches_q->rows > 1) {
	too_many_matches($match_id);
    }

    my ($blast_target_db, $defline, $blast_program) = $blast_matches_q->fetchrow_array();
    my $annot_target_desc = "Unigene <b>$blast_program</b> search against <b>$blast_target_db</b>";
    @match_detail = ($annot_target_desc, $defline);


#data returned by $blast_unig_link_q is:
#u.unigene_id, g.comment, bh.score, bh.evalue, bh.identity_percentage, bh.apply_start, bh.apply_end

    $blast_unig_link_q->execute($match_id) or $page->error_page("Couldn't get blast unigene links\n");

    while (my ($unig_id, $build_desc,  $blast_score, $evalue, $identity_pct, $span_start, $span_end)=$blast_unig_link_q->fetchrow_array()){
	my $span_ln=abs($span_end - $span_start);
	$identity_pct=sprintf "%7.2f", $identity_pct;
	my $unig_desc="<tr><td></td><td align=\"left\" nowrap=\"nowrap\"><a href=\"$unig_link$unig_id\">SGN-U$unig_id</a></td><td align=\"left\" nowrap=\"nowrap\">$build_desc;</td><td align=\"left\" nowrap=\"nowrap\"> matched with $identity_pct% identity over ${span_ln}bp (e-value $evalue)</td></tr>";
	push @unigene_list, [$unig_desc, $blast_score];
    }

}


#get the data ready for display
my @results;

#match data is:
#[annotated_data_description, annotation_text];

my $match_text=$match_detail[1];

#strip <br /> tags.
#this is for the current specific version of manual annotation
#it is a kludge, there should be a text only searcheable field
# and a separate html enhanced text display field in the db

$match_text =~ s/\<br\>/  /g;

#insert <br /> in front of genbank id tags to break up long deflines
$match_text =~ s/(gi\|)/<br \/>$1/g;

my $web_format="
	<tr><td bgcolor=\"$desc_colour\" align=\"left\" nowrap=\"nowrap\">$match_detail[0]</td></tr>
        <tr><td colspan=\"2\">$match_text</td></tr>";

if (@unigene_list){
    $web_format .= "
<tr><td colspan=\"2\" align=\"left\" nowrap=\"nowrap\"><br />Unigenes containing this annotation:</td></tr>
<tr><td colspan=\"2\" align=\"left\" nowrap=\"nowrap\">
<table align=\"left\" cellspacing=\"2\" cellpadding=\"0\" border=\"0\">
";


#unigene data is:
#[unigene_line, sorting_value]
# the unigene line has 4 columns

    foreach (sort{$$b[1] <=> $$a[1]} @unigene_list){
	$web_format .= "$$_[0]";
    }
    $web_format .="</table></td></tr>";


    $web_format .= "<tr><td colspan=\"2\">&nbsp;</td></tr>";
    push @results, $web_format;
}


#start printing the page
$page->header();

print<<EOF
    <table align="center" cellspacing="0" cellpadding="2" border="0" width="100%">
    <tr><td colspan="2" bgcolor="#FFFFFF"><br /></td></tr>
@results
    <tr><td colspan="2" bgcolor="#FFFFFF"><br /></td></tr>
</table>
EOF
;

$page->footer();





sub no_matches {
  my ($match_id) = @_;

  $page->header();

  print <<EOF;

  <p>ERROR:  No matches; should return at least one match for $match_id</p>
EOF

  $page->footer();

  exit 0;
}

sub too_many_matches {
  my ($match_id) = @_;

  $page->header();

  print <<EOF;

  <p>ERROR:  Too many matches: should only return one match for $match_id</p>

EOF

  $page->footer();

  exit 0;
}

sub null_request {

  $page->header();

  print <<EOF;

  <p><b>No match_id was found</b></p>

EOF

  $page->footer();

  exit 0;
}

