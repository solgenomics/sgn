#!/usr/bin/perl -w

######################################################################
#
#  This program displays statistics on the progress of the overgo
#  plating project as reflected by the physical database.
#
#  As of version 1.2 this program consults both the database and the
#  summary report files written to the directory
#
#    ~/sgn/pwd/support_data/physicalmapping/report
#
#  in order to determine the necessary statistics.
#  However, in some cases it still cheats by just statically setting 
#  values.
#
######################################################################

use strict;
use CXGN::Page;
use CXGN::DB::Physical;
use CXGN::DB::Connection;

use CXGN::Page::FormattingHelpers qw/blue_section_html columnar_table_html info_table_html/;

my $page = CXGN::Page->new('Overgo Stats', 'Robert and friends');
my $map_id = 9; # always, for now.


# Definitions;
our $plausible_bacs = 1;
our $genetic_threshold = "5.0";
our $number_chromos = 12;
our $preset_date = "20030909";
our $sgnblue = '#ccccff';
our $arizona_tom_fpc_page = 'http://www.genome.arizona.edu/fpc/tomato/';
our $physical_abstract_page = '/cview/map.pl?map_id=1&amp;physical=1';
our $physical_overview_page = '/cview/map.pl?map_id=1&amp;physical=1';
our $plate_design_page = '/maps/physical/list_overgo_plate_probes.pl?plate_no=';
our $list_bacs_by_plate = '/maps/physical/list_bacs_by_plate.pl?by_plate=';
our $explanation_page = 'overgo_process_explained.pl';
our %months = ('01' => 'January', '02' => 'February', '03' => 'March', 
	      '04' => 'April', '05' => 'May', '06' => 'June',
	      '07' => 'July', '08' => 'August', '09' => 'September',
	      '10' => 'October', '11' => 'November', '12' => 'December');

# Connect to the database.
my $dbh = CXGN::DB::Connection->new('physical');

######################################################################
#
#  This is where we should pull all of the above fresh from the DB.
#
######################################################################

# Figure out the last date on which these data were updated.
my ($overgo_version, $overgo_date) = CXGN::DB::Physical::get_current_overgo_version_and_updated_on($dbh);
if ($overgo_date =~ /^(\d\d\d\d-\d\d-\d\d)/) {
    $overgo_date = $1;
} else {
  $page->message_page( "error","<I>ERROR: Incorrectly formatted overgo plating date.</I>\n" );
}

my ($fpc_version, $fpc_date) = CXGN::DB::Physical::get_current_fpc_version_and_date($dbh);

#warn "got dates '$overgo_date' and '$fpc_date'\n";
my @dates = sort ($overgo_date, $fpc_date);
my $most_recent_date = pop @dates;
$most_recent_date ||= $preset_date;

my $last_date;
if ($most_recent_date =~ /^(\d\d\d\d)-?(\d\d)-?(\d\d)/) {
    $last_date = $months{$2} . " " . $3 . ", " . $1;
} else {
  $page->message_page("error", "<I>ERROR: Incorrectly formatted string $most_recent_date.</I>\n" );
}

#warn "hi";

# Get the total number of BACs considered.
my $number_of_bacs = CXGN::DB::Physical::get_total_number_of_bacs($dbh);

# BACs which hit the plate at all (ie. have a match to at least one pool.
my $bac_partial_hits_sth = $dbh->prepare("SELECT COUNT(DISTINCT bac_id) FROM overgo_results");
$bac_partial_hits_sth->execute;
my ($bac_partial_hits) = $bac_partial_hits_sth->fetchrow_array;
$bac_partial_hits_sth->finish;

# Get all plates numbers.
my $plate_numbers_sth = $dbh->prepare("SELECT DISTINCT plate_number FROM overgo_plates");
$plate_numbers_sth->execute;
my %unprocessed_plates;
while (my ($pn) = $plate_numbers_sth->fetchrow_array) {
    $unprocessed_plates{$pn} = 1;
}
$plate_numbers_sth->finish;

# List all plates processed to date.
my $proc_plate_sth = $dbh->prepare("SELECT DISTINCT op.plate_number, op.plate_size, op.empty_wells FROM overgo_plates AS op INNER JOIN overgo_results AS ores ON op.plate_id=ores.overgo_plate_id ORDER BY op.plate_number");
my %processed_plates;
$proc_plate_sth->execute;
my ($total_wells, $total_empty, $total_matching_wells, $total_matching_bacs);
while (my ($pn, $wells, $empty) = $proc_plate_sth->fetchrow_array) {
    delete $unprocessed_plates{$pn};
    my $wells_with_hits = CXGN::DB::Physical::count_wells_with_plausible_hits_on_plate_n($dbh, $pn, $overgo_version, $map_id);
    my $bac_hits_on_plate = CXGN::DB::Physical::count_all_bacs_which_hit_plate_n($dbh, $pn, $overgo_version, $map_id);
    $processed_plates{$pn} = [ qq|<a href="$plate_design_page$pn">Plate $pn</a>|,
			       ($wells - $empty),
			       $empty,
			       $wells_with_hits,
			       qq|<a href="$list_bacs_by_plate$pn">$bac_hits_on_plate</a>|,
			     ];
    $total_wells += $wells;
    $total_empty += $empty;
    $total_matching_wells += $wells_with_hits;
    $total_matching_bacs += $bac_hits_on_plate;
}
$proc_plate_sth->finish;

#warn "hello there";

# Prepare a listing of unprocessed plates.
my $unprocessed_plates_table = 
  do {
    my $unproc_width = 5;
    my $unproc_row = 0;
    my @unproc_list = (sort {$a <=> $b} keys %unprocessed_plates);
    my @table;
    while(my @row = splice @unproc_list,0,$unproc_width) {
      push @table,\@row;
    }
    columnar_table_html(data=>\@table);
  } if %unprocessed_plates;

# Count the total number of ambiguous bacs.

my $ambig_sth = $dbh->prepare("SELECT COUNT(DISTINCT bac_id) FROM tentative_overgo_associations WHERE overgo_version=?");
$ambig_sth->execute($overgo_version);
my ($ambiguous_bacs) = $ambig_sth->fetchrow_array;
$ambig_sth->finish;

#warn "one";

# Now work out FPC stats.
my $total_contigged_bacs_sth = $dbh->prepare("SELECT COUNT(DISTINCT ba.bac_id) FROM bac_contigs AS bc INNER JOIN bac_associations AS ba ON bc.bac_contig_id=ba.bac_contig_id INNER JOIN ba_plausibility AS bap using(bac_assoc_id) WHERE bc.fpc_version=? AND bap.map_id=?");
$total_contigged_bacs_sth->execute($fpc_version, $map_id);
my ($total_contigged_bacs) = $total_contigged_bacs_sth->fetchrow_array;
$total_contigged_bacs_sth->finish;

my $total_bac_singletons = $number_of_bacs - $total_contigged_bacs;

#warn "two";

# Stats for deconvolution.
my $plausible_bacs_sth = $dbh->prepare("SELECT COUNT(DISTINCT bac_id) FROM overgo_associations INNER JOIN oa_plausibility AS oap USING(overgo_assoc_id) WHERE overgo_version=? AND oap.plausible=1 AND oap.map_id=?");
$plausible_bacs_sth->execute($overgo_version, $map_id);
my ($plausible_bacs_count) = $plausible_bacs_sth->fetchrow_array;
$plausible_bacs_sth->finish;

#warn "three";

my $distinct_contigs_sth = $dbh->prepare("select count(distinct bac_contig_id) from plausible_bacs_in_all_contigs");
$distinct_contigs_sth->execute();
#warn "how are you doing today?";

my ($distinct_contigs_count) = $distinct_contigs_sth->fetchrow_array;
$distinct_contigs_sth->finish;

#warn "overgo_version $overgo_version, fpc_version $fpc_version, map_id $map_id";
my $bacs_in_distinct_contigs_sth = $dbh->prepare("select count(distinct bac_id) from plausible_bacs_in_all_contigs;");
$bacs_in_distinct_contigs_sth->execute();
my ($bacs_in_distinct_contigs_count) = $bacs_in_distinct_contigs_sth->fetchrow_array;
$bacs_in_distinct_contigs_sth->finish;

#warn "four";

my $plausible_contigs_sth = $dbh->prepare("select count(distinct bac_contig_id) from plausible_bacs_in_all_contigs where bac_plausible = 1;");
$plausible_contigs_sth->execute();
my ($plausible_contigs_count) = $plausible_contigs_sth->fetchrow_array;
$plausible_contigs_sth->finish;

#warn "five";


 

######################################################################
#
#  And this is where we display the page.
#
######################################################################

#warn "nice day to print some html, isn't it?";

$page->header("Overgo plating results as of " . $last_date,"Overgo plating results as of " . $last_date);

my $number_of_plates = (scalar (keys %processed_plates));

# Overview of the Overgo Plating done to date.
my @bleh = ( qq|Total number of <a href="$explanation_page#bacs">BACs</a>| => $number_of_bacs,
	     qq|Total number of <a href='$explanation_page#probes'>probes</a>| => $total_wells,
	     qq|Number of <a href='$explanation_page#plates'>overgo plates</a> processed so far| => $number_of_plates,
	     qq|Number of BACs which <a href='$explanation_page#hittheplates'>hit the plates</a> one or more times| => $bac_partial_hits,
	     qq|Number of BACs which <a href='$explanation_page#ambiguity'>unambiguously</a> matched one or more plates with a row, column match| => $total_matching_bacs,
	     qq|Number of BACs which <a href='$explanation_page#ambiguity'>ambiguously</a> matched one or more plates| => $ambiguous_bacs,
	     qq|Average number of <a href='$explanation_page#ambiguity'>unambiguous</a> BACs matching each probe| => sprintf("%.2f", ($total_matching_bacs / $total_wells)),
	   );

sub gen_summary {
  my $html;
  while(my ($field,$value) = splice @_,0,2) {
    $html .= "<b>$field:</b> $value<br />\n";
  }
  $html;
}

print blue_section_html('Summary',gen_summary(@bleh));

my @headings = ( qq|<a href="$explanation_page#plates">Overgo plate</a>|,
		 qq|<a href="$explanation_page#probes">Probes</a>|,
		 qq|<a href="$explanation_page#emptywells">Empty wells</a>|,
		 qq|<a href="$explanation_page#anchorpoint">Anchor points</a>|,
		 qq|<a href="$explanation_page#bacs">BACs</a> matching plate|,
	       );


print blue_section_html('Plates overview',
			info_table_html('Processed plates' =>
					columnar_table_html(headings => \@headings,
							    data     => [@processed_plates{sort {$a <=> $b} keys %processed_plates},
									 ['<b>Total</b>',$total_wells,$total_empty,$total_matching_wells,$total_matching_bacs],
									],
							    __border => 1,
							   ),
					'Unprocessed plates' => $unprocessed_plates_table || '<span class="ghosted">All plates processed.</span>',
					__border => 0,
				       )
		       );

print blue_section_html(qq|Overview of <a href="$explanation_page#fpc_contigging">BAC contigging</a>|,<<EOH);
<b>NB. -</b> These data are taken from the <a href='$arizona_tom_fpc_page' target='ARIZONA'>Tomato Physical Mapping Project</a> pages of the Arizona Genomics Institute, who are using the FPC process to assemble BACs into contigs. <br />
<b>Number of BACs Contigged:</b> $total_contigged_bacs <br />
<b>Number of BAC Singletons:</b> $total_bac_singletons 
EOH

@bleh = (qq|Number of unique <a href="$explanation_page#anchorpoint">anchor points</a> for BAC <-> genetic map associations|
	 => $total_matching_wells,
	 qq|Number of BACs which <a href='$explanation_page#plausible'>plausibly</a> matched one chromosome/position|
	 => $plausible_bacs_count,
	 qq|Contigs|
	 => "$distinct_contigs_count contigs made of $bacs_in_distinct_contigs_count plausible BACs",
	 qq|Mean number of anchor points per chromosome| 
	 => sprintf("%.2f", ($total_matching_wells / $number_chromos)),
	 qq|Mean number of BACs per chromosome|
	 => sprintf("%.2f", ($total_matching_bacs / $number_chromos)),
	 qq|Mean number of BAC contigs per chromosome|
	 => sprintf("%.2f", ($plausible_contigs_count / $number_chromos)),
	 qq|Mean number of BACs per anchor point|
	 => sprintf("%.2f", ($total_matching_bacs / $total_matching_wells)),
	);

print blue_section_html('Physical map statistics',<<EOH.gen_summary(@bleh));
$total_matching_bacs BACs matched well to one or more probe markers on the F2-2000 Genetic map.<br />
These BACs were then screened to find which ones only matched to markers within a small area of one chromosome - no more than <b>$genetic_threshold cM</b> across.<br />
EOH
# Commented out at Eileen's request.
#print "<b>Number of Contigs where all BACs fell on the same chromosome:</b> " . $plausible_contigs_count . "<br />\n";

print blue_section_html
  ('Links',
   "<ul>".join("\n",
	       map {"<li>$_</li>"} ( qq|<a href='$physical_abstract_page'>View the Abstract for the physical F2-2000 map.</a>|,
				     qq|<a href='$explanation_page'>Explanation of the Overgo Plating process</a>|,
				     qq|<a href='$physical_overview_page'>View an overview of all chromosomes of the physical map.</a>|,
				     qq|<a href='$arizona_tom_fpc_page' target='ARIZONA'>View the FPC pages for the physical mapping project.</a>|,
				   )
	      )
   ."</ul>\n"
  );


$page->footer;
