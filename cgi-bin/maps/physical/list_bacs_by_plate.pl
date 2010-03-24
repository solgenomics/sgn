######################################################################
#
#  This is a script to list BACs from the database.  It will perform
#  various types of BAC listing operations, depending on the calling
#  paramaters.
#
######################################################################

use strict;
use CXGN::Page;
use CXGN::DB::Physical;
use CXGN::DB::Connection;
use CXGN::Page::FormattingHelpers qw/page_title_html blue_section_html columnar_table_html/;

my $map_id = CXGN::DB::Physical::get_current_map_id();
warn $map_id;

# Presets.
my $link_pages = {'marker_page' => '/search/markers/markerinfo.pl?marker_id=',
		  'map_page' => '/cview/map.pl?map_id=',
		  'overgo_report_page' => '/maps/physical/overgo_stats.pl',
		  'agi_page' => 'http://www.genome.arizona.edu/fpc/tomato/',
		  'bac_page' => '/maps/physical/clone_info.pl?bac_id=',
		  'sgn_search_page' => '/search/direct_search.pl',
		  'list_bacs_by_plate' => '/maps/physical/list_bacs_by_plate.pl?by_plate=',
		  'plate_design_page' => '/maps/physical/list_overgo_plate_probes.pl?plate_no='};
$$link_pages{'physical_map_page'} = $$link_pages{'map_page'} . '9&amp;physical=1';
$$link_pages{'contig_page'} = $$link_pages{'agi_page'};

# Connect to the physical database.
my $dbh = CXGN::DB::Connection->new('physical');
our $page = CXGN::Page->new( "BAC List by Plate", "Robert Ahrens");

# Parse arguments.
my %params = $page->get_all_encoded_arguments;

my $by_plate = $params{'by_plate'} || list_page($dbh, 0, $link_pages);
print page_title_html("Plate $by_plate");
my $overgo_version = $params{'overgo_version'} || 0;
my $fpc_version = $params{'fpc_version'} || 0;

# Get version stuff from the db.
$fpc_version ||= CXGN::DB::Physical::get_current_fpc_version($dbh);
$overgo_version ||= CXGN::DB::Physical::get_current_overgo_version($dbh);

# Get max bacid and prepare the arrays.
my $max_bacid_sth = $dbh->prepare("SELECT bac_id FROM bacs ORDER by bac_id DESC");
$max_bacid_sth->execute();
my $max_bacid = $max_bacid_sth->fetchrow_array;
$max_bacid_sth->finish;
my @bacs;
my @contigs;
for (my $i=0; $i<=$max_bacid; $i++) {
    $bacs[$i] = undef;
    $contigs[$i] = undef;
}

# Get the FPC information.
my $fpc_stm = "SELECT b.bac_id, bc.contig_name, bc.bac_contig_id FROM bacs AS b INNER JOIN bac_associations AS ba ON b.bac_id=ba.bac_id INNER JOIN bac_contigs AS bc ON ba.bac_contig_id=bc.bac_contig_id WHERE b.bad_clone!=1 AND bc.fpc_version=?";
my $fpc_sth = $dbh->prepare($fpc_stm);
$fpc_sth->execute($fpc_version);
while (my ($bac_id, $contig, $ctg_id) = $fpc_sth->fetchrow_array) {
    $contigs[$bac_id] = $contig;
}

# Get that BAC list plus overgo information.
my $sgn = $dbh->qualify_schema('sgn');
my $overgo_stm = "SELECT b.cornell_clone_name, b.arizona_clone_name, b.bac_id, ma.alias, ma.marker_id FROM bacs AS b INNER JOIN overgo_associations AS oa ON b.bac_id=oa.bac_id INNER JOIN oa_plausibility AS oap USING(overgo_assoc_id) INNER JOIN probe_markers AS pm ON oa.overgo_probe_id=pm.overgo_probe_id INNER JOIN overgo_plates AS op ON pm.overgo_plate_id=op.plate_id INNER JOIN $sgn.marker_alias AS ma ON pm.marker_id=ma.marker_id WHERE b.bad_clone!=1 AND oap.plausible=1 AND oa.overgo_version=? AND op.plate_number=? AND oap.map_id=? AND ma.preferred=true";
my $overgo_sth = $dbh->prepare($overgo_stm);
$overgo_sth->execute($overgo_version, $by_plate, $map_id);
my $baccount=0;
while (my ($clone, $az_name, $bacid, $probe, $mrkr_dbid) = $overgo_sth->fetchrow_array) {
    $baccount ++;
    $bacs[$bacid] = [ qq|<a href="$$link_pages{bac_page}$bacid">$clone</a>|,
		      $az_name,
		      qq|<a href="$$link_pages{marker_page}$mrkr_dbid">$probe</a>|,
		      $contigs[$bacid]
		    ];
}

# Print the list of viable plates if this plate is not one of them.
$baccount || list_page($dbh, $by_plate, $link_pages);

# Print the page.
$page->header("BAC list for plate $by_plate");
print page_title_html(qq|BAC list for <a href="$$link_pages{plate_design_page}$by_plate">plate $by_plate</a> ($baccount BACs)|);

my @headings = ('BAC','AGI Clone name','Probe matches','FPC Contigs');

my @rows = grep {$_} @bacs;

print blue_section_html('BAC list',
			columnar_table_html(headings => \@headings,
					    data => \@rows,
					    __alt_freq => 3,
					    __border => 1,
					   )
			. plate_link_list($dbh, $by_plate, $link_pages)
		       );


# Links.
print_links($link_pages, 0, $by_plate);
$page->footer;



######################################################################
#
#  Subroutines
#
######################################################################

sub list_page {

    my ($dbh, $by_plate, $link_pages) = @_;
    my $title = "Overgo plate BAC list";
    our $page = CXGN::Page->new( $title, "Robert Ahrens");
    $page->header;
    print page_title_html($title);
    if ($by_plate) {
	print "No data for plate $by_plate are currently loaded in the SGN database.\n";
    }
    print_full_plate_list($dbh, $by_plate, $link_pages);
    print_links($link_pages, 4);
    $page->footer;
    exit;

}


sub plate_link_list {

    my ($dbh, $by_plate, $link_pages, $overgo_version) = @_;

    # Get the data.
    my $stm = "SELECT DISTINCT op.plate_number FROM overgo_plates AS op INNER JOIN probe_markers AS pm ON op.plate_id=pm.overgo_plate_id INNER JOIN overgo_associations AS oa ON pm.overgo_probe_id=oa.overgo_probe_id " . ($overgo_version ? " WHERE oa.overgo_version=$overgo_version " : "") . "ORDER  BY op.plate_number";
    my $sth = $dbh->prepare($stm);
    $sth->execute();
    # Print the section.
    my $html = qq|<div style="text-align: center; font-size: 120%; margin-bottom: 2em;">\n Go to plate: |.
      join('&nbsp;&nbsp;',
	   map {
	     my $pn = $_->[0];
	     $pn == $by_plate ? "<b>$pn</b>"
	       : qq|<a href="$$link_pages{list_bacs_by_plate}$pn">$pn</a>|;
	   } @{$sth->fetchall_arrayref}
	  )
	."</div>\n"
	  .qq|<span class="tinytype">Please note that this list contains only those BACs which have a <i>clean and unambiguous</i> match to a probe on plate $by_plate.  A complete list of BACs in this project would run into hundreds or thousands and is not available on SGN at this time.  However, downloadable data from this project will be forthcoming to our ftp site shortly.</span>|;

    $sth->finish;

    return $html;
}


sub print_full_plate_list {

    my ($dbh, $by_plate, $link_pages, $overgo_version) = @_;
    # Get the data.
    my $stm = "SELECT DISTINCT op.plate_number FROM overgo_plates AS op INNER JOIN probe_markers AS pm ON op.plate_id=pm.overgo_plate_id INNER JOIN overgo_associations AS oa ON pm.overgo_probe_id=oa.overgo_probe_id " . ($overgo_version ? " WHERE oa.overgo_version=$overgo_version " : "") . "ORDER BY op.plate_number";
    my $sth = $dbh->prepare($stm);
    $sth->execute();

    # Print the section.
    print blue_section_html('BACs listed by overgo plate',qq|<center>\n|.
			    do {
			      my @rows;
			      while (my ($pn) = $sth->fetchrow_array) {
				my $bac_count = CXGN::DB::Physical::count_all_bacs_which_hit_plate_n($dbh, $pn, $overgo_version, $map_id);
				push @rows, [qq|<a href="$$link_pages{plate_design_page}$pn"><b>$pn</b></a>|,
					     qq|<a href="$$link_pages{list_bacs_by_plate}$pn">$bac_count BACs</a>|,
					    ];
			      }
			      columnar_table_html(headings => ['Plate','# BACs'],
						  data => \@rows,
						  __border => 1,
						  __tableattrs => 'width="60%" cellspacing="0" summary=""',
						 );
			    }
			    .qq|</center>\n|
			   );
    $sth->finish;
}


sub print_links {

    my ($link_pages, $colspan, $plate_no) = @_;
    my $pnlink = $plate_no ? qq|<li><a href="$$link_pages{plate_design_page}$plate_no">Show Overgo Probes on plate $plate_no</a></li>| : '';
    print blue_section_html('Related Pages',<<EOH);
<ul>
$pnlink
<li><a href="$$link_pages{overgo_report_page}">Report on the Overgo Plating process</a></li>
<li><a href="$$link_pages{physical_map_page}">Tomato Physical Map on SGN</a></li>
<li><a href="$$link_pages{agi_page}">Web FPC pages at the Arizona Genomics Institute</a></li>
<li><a href="$$link_pages{sgn_search_page}">Search SGN</a></li>
</ul>
EOH

}
