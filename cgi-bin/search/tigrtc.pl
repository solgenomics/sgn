#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::DB::Connection;

use CXGN::Page::FormattingHelpers qw/ page_title_html columnar_table_html /;

# This script receives and executes a search of SGN's unigenes based on TIGR
# TC numbers. It works by searching first our local tables of TIGR's TC
# tracking and membership, isolating the members of the relevant *current*
# TIGR TCs and tracking down what current SGN unigenes they are in.

my $page = CXGN::Page->new( "TIGR TC search", "Rob");

my ($tigr_tc, $tcindex_id) = $page->get_arguments("tigr_tc","tcindex_id");


# validate tigr_tc arg
null_request($page) if $tigr_tc eq '';
my ($search_id) = $tigr_tc =~ m/(?:TC\s*|)([0-9]+)/i;

not_recognized($page,$tigr_tc) unless $search_id;

my $dbh = CXGN::DB::Connection->new('sgn');

# look up the current TC ID for the given TC
my $current_ids = $dbh->selectcol_arrayref(<<EOQ,undef, $search_id, $search_id, $tcindex_id );
SELECT current_tc_id
FROM tigrtc_tracking
WHERE (tc_id=? or current_tc_id=?)
  AND tcindex_id=?
GROUP BY current_tc_id
EOQ

@$current_ids or no_current_tcs($page, $tigr_tc);

# figure out what we should say about whether this TC is current
my $not_current = do {
  if ( $current_ids->[0] != $search_id ) {
    if ( @$current_ids == 1) {
       "<p><b>Note: Your search ($tigr_tc) specified an old TC identifer and was mapped to current TIGR TC$current_ids->[0]</b></p><br />";
    } elsif( @$current_ids ) {
      "<p><b>Note:</b>TC$search_id is not a current TC identifier. TC$search_id was mapped to more than one current TC.</p><br />";
    } else {
      die 'this point should not be reached';
    }
  } else {
    ''
  }
};


$page->header('TIGR TC -> SGN-U Mapping');

print $not_current;

foreach my $tc ( @$current_ids ) {

    my $ug_summary = $dbh->selectall_arrayref(<<EOQ, undef, $tc, $tcindex_id);
SELECT (select groups.comment from groups where group_id = unigene_build.organism_group_id limit 1) as series,
       unigene.unigene_id,
       count(*)
FROM est
JOIN unigene_member USING (est_id)
JOIN unigene USING (unigene_id)
JOIN unigene_build USING (unigene_build_id)
JOIN tigrtc_membership tm ON (est.read_id=tm.read_id)
WHERE tm.tc_id = ? and tm.tcindex_id = ?
 AND unigene_build.status='C'
GROUP BY series, unigene.unigene_build_id, unigene.unigene_id
EOQ

    print page_title_html("SGN unigenes having member sequences in common with TIGR TC$tc");

    print columnar_table_html( headings => ['Build Series','SGN-U'],
			       data => [
					map {
					  my ( $build, $unigene_id, $count ) = @$_;
					  [ $build,
					    qq|<a href="/search/unigene.pl?unigene_id=$unigene_id">SGN-U$unigene_id</a> ($count common member|.($count > 1 ? 's' : '').')',
					  ]
					} @$ug_summary
				       ],
			     );
}

print <<EOF;
</table>
<br />
EOF

$page->footer();

exit;



############ SUBROUTINES #########3


sub no_current_tcs {
  my ($page,$tigr_tc) = @_;

  $page->header();

  print <<EOF;

  <p><b>Your request ($tigr_tc) does not track to any current TIGR TC identifiers known to SGN. Please try your search at <a href="http://www.tigr.org/tdb/tgi/">TIGR</a>. </b>
</p><br /><br />
EOF

  $page->footer();

  exit 0;
}

sub not_recognized {
  my ($page,$tigr_tc) = @_;

  $page->header();

  print <<EOF;

  <p><b>Your request ($tigr_tc) is not recognized as a TIGR TC number. Please enter the TC number alone, optionally prefixed with "TC".</b></p>
<br /><br />
EOF

  $page->footer();

  exit 0;

}

sub null_request {
  my ($page) = @_;

  $page->header();

  print <<EOF;

  <p><b>No TIGR TC number was specified.</b></p>
<br /><br />
EOF

  $page->footer();

  exit 0;
}


