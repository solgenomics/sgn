#!/usr/bin/perl -w
use strict;
use warnings;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html page_title_html html_break_string/;
use CXGN::Chromatogram;
use URI::Escape;
use CXGN::Tools::Text qw | sanitize_string |;
use CatalystX::GlobalContext '$c';
use SGN::I18N;
use HTML::Entities qw(encode_entities);
my SGN::I18N $i18n = eval { $c && $c->i18n };
my $est_version_explanation = encode_entities(($i18n ? $i18n->p("global.est_detail.version_explanation", "Note: Some unigenes listed here are assembled from different versions of the sequence displayed above. Note SGN-E# in left column. All versions were derived from the same chromatogram") : "Note: Some unigenes listed here are assembled from different versions of the sequence displayed above. Note SGN-E# in left column. All versions were derived from the same chromatogram"));
my $render_i18n_html = sub {
    my ($message, $slots) = @_;
    my $html = encode_entities($message);
    # One substitution pass: inserted data cannot become another markup slot.
    $html =~ s/(__SGN_UI_[A-Z0-9_]+__)/exists $slots->{$1} ? $slots->{$1} : $1/ge;
    return $html;
};
my $est_ui_not_found_title = encode_entities(($i18n ? $i18n->p("global.final_caption.direct_search_result_not_found", "Direct Search Result - Not Found") : "Direct Search Result - Not Found"));
my $est_ui_invalid_title = encode_entities(($i18n ? $i18n->p("global.final_caption.not_found_search_invalid", "Not Found - Search Invalid") : "Not Found - Search Invalid"));
use CXGN::DB::Connection;

my $est_i18n_request = encode_entities($i18n ? $i18n->p('global.est.request', 'Request:') : 'Request:');
my $est_i18n_match = encode_entities($i18n ? $i18n->p('global.est.match', 'Match:') : 'Match:');
my $est_i18n_request_from = encode_entities($i18n ? $i18n->p('global.est.request_from', 'Request From:') : 'Request From:');
my $est_i18n_match_type = encode_entities($i18n ? $i18n->p('global.est.match_type', 'Match Type:') : 'Match Type:');
my $est_i18n_microarray = encode_entities($i18n ? $i18n->p('global.est.microarray', 'Microarray:') : 'Microarray:');
my $est_i18n_order_clone = encode_entities($i18n ? $i18n->p('global.est.order_clone', 'Order Clone') : 'Order Clone');
my $est_i18n_order = encode_entities($i18n ? $i18n->p('global.est.order', 'Order') : 'Order');
my $est_i18n_ordering_not_available = encode_entities($i18n ? $i18n->p('global.est.ordering_not_available', 'Ordering Not Available') : 'Ordering Not Available');
my $est_i18n_sgn_id = encode_entities($i18n ? $i18n->p('global.est.sgn_id', 'SGN ID:') : 'SGN ID:');
my $est_i18n_sgn_trace_id = encode_entities($i18n ? $i18n->p('global.est.sgn_trace_id', 'SGN-ID:') : 'SGN-ID:');
my $est_i18n_clone_name = encode_entities($i18n ? $i18n->p('global.est.clone_name', 'Clone name:') : 'Clone name:');
my $est_i18n_library_name = encode_entities($i18n ? $i18n->p('global.est.library_name', 'Library Name:') : 'Library Name:');
my $est_i18n_organism = encode_entities($i18n ? $i18n->p('global.est.organism', 'Organism:') : 'Organism:');
my $est_i18n_tissue = encode_entities($i18n ? $i18n->p('global.est.tissue', 'Tissue:') : 'Tissue:');
my $est_i18n_development_stage = encode_entities($i18n ? $i18n->p('global.est.development_stage', 'Development Stage:') : 'Development Stage:');
my $est_i18n_funding_organization = encode_entities($i18n ? $i18n->p('global.est.funding_organization', 'Funding Organization:') : 'Funding Organization:');
my $est_i18n_view = encode_entities($i18n ? $i18n->p('global.est.view', 'View') : 'View');
my $est_i18n_download = encode_entities($i18n ? $i18n->p('global.est.download', 'Download') : 'Download');
my $est_i18n_facility_assigned_id = encode_entities($i18n ? $i18n->p('global.est.facility_assigned_id', 'Facility Assigned ID:') : 'Facility Assigned ID:');
my $est_i18n_submitter = encode_entities($i18n ? $i18n->p('global.est.submitter', 'Submitter:') : 'Submitter:');
my $est_i18n_sequencing_facility = encode_entities($i18n ? $i18n->p('global.est.sequencing_facility', 'Sequencing Facility:') : 'Sequencing Facility:');
my $est_i18n_clone = encode_entities($i18n ? $i18n->p('global.est.clone', 'Clone:') : 'Clone:');
my $est_i18n_trace = encode_entities($i18n ? $i18n->p('global.est.trace', 'Trace:') : 'Trace:');
my $est_i18n_est = encode_entities($i18n ? $i18n->p('global.est.est', 'EST:') : 'EST:');
my $est_i18n_direction = encode_entities($i18n ? $i18n->p('global.est.direction', 'Direction:') : 'Direction:');
my $est_i18n_facility = encode_entities($i18n ? $i18n->p('global.est.facility', 'Facility:') : 'Facility:');
my $est_i18n_problems = encode_entities($i18n ? $i18n->p('global.est.problems', 'Problems:') : 'Problems:');
my $est_i18n_processed_by = encode_entities($i18n ? $i18n->p('global.est.processed_by', 'Processed By:') : 'Processed By:');
my $est_i18n_basecalling = encode_entities($i18n ? $i18n->p('global.est.basecalling', 'Basecalling Software:') : 'Basecalling Software:');
my $est_i18n_vector_signature = encode_entities($i18n ? $i18n->p('global.est.vector_signature', 'Vector Signature:') : 'Vector Signature:');
my $est_i18n_sequence_entropy = encode_entities($i18n ? $i18n->p('global.est.sequence_entropy', 'Sequence Entropy:') : 'Sequence Entropy:');
my $est_i18n_expected_error = encode_entities($i18n ? $i18n->p('global.est.expected_error', 'Expected Error Rate:') : 'Expected Error Rate:');
my $est_i18n_quality_trim = encode_entities($i18n ? $i18n->p('global.est.quality_trim', 'Quality Trim Threshold:') : 'Quality Trim Threshold:');
my $est_i18n_sequence_id = encode_entities($i18n ? $i18n->p('global.est.sequence_id', 'Sequence Id:') : 'Sequence Id:');
my $est_i18n_length = encode_entities($i18n ? $i18n->p('global.est.length', 'Length:') : 'Length:');
my $est_i18n_status = encode_entities($i18n ? $i18n->p('global.est.status', 'Status:') : 'Status:');
my $est_i18n_current_builds = encode_entities($i18n ? $i18n->p('global.est.current_builds', 'Current Unigene builds') : 'Current Unigene builds');
my $est_i18n_unknown = encode_entities($i18n ? $i18n->p('global.est.unknown', 'Unknown') : 'Unknown');
my $est_i18n_follow_unigene = encode_entities($i18n ? $i18n->p('global.est.follow_unigene', 'Follow SGN-U# link for detailed information and annotations') : 'Follow SGN-U# link for detailed information and annotations');
my $est_i18n_search_info = encode_entities($i18n ? $i18n->p('global.est.search_info', 'Search information') : 'Search information');
my $est_i18n_clone_info = encode_entities($i18n ? $i18n->p('global.est.clone_info', 'Clone information') : 'Clone information');
my $est_i18n_additional_sequencing = encode_entities($i18n ? $i18n->p('global.est.additional_sequencing', 'Additional sequencing') : 'Additional sequencing');
my $est_i18n_sequence = encode_entities($i18n ? $i18n->p('global.est.sequence', 'Sequence') : 'Sequence');
my $est_i18n_unigenes = encode_entities($i18n ? $i18n->p('global.est.unigenes', 'Unigenes') : 'Unigenes');
my $est_i18n_chromatogram = encode_entities($i18n ? $i18n->p('global.est.chromatogram', 'Chromatogram') : 'Chromatogram');
my $est_i18n_quality_processing = encode_entities($i18n ? $i18n->p('global.est.quality_processing', 'Quality processing') : 'Quality processing');
my $est_i18n_show_hierarchy = encode_entities($i18n ? $i18n->p('global.est.show_hierarchy', '[Show information hierarchy]') : '[Show information hierarchy]');
my $est_i18n_information_hierarchy = encode_entities($i18n ? $i18n->p('global.est.information_hierarchy', 'Information Hierarchy') : 'Information Hierarchy');
my $est_i18n_no_clone_info = encode_entities($i18n ? $i18n->p('global.est.no_clone_info', 'No clone information found') : 'No clone information found');
my $est_i18n_no_chromatogram = encode_entities($i18n ? $i18n->p('global.est.no_chromatogram', 'No chromatogram information found for this sequence') : 'No chromatogram information found for this sequence');
my $est_i18n_no_additional_reads = encode_entities($i18n ? $i18n->p('global.est.no_additional_reads', 'No additional reads found.') : 'No additional reads found.');
my $est_i18n_microarray_missing = encode_entities($i18n ? $i18n->p('global.est.microarray_missing', 'This clone is not found on any microarray') : 'This clone is not found on any microarray');
my $est_i18n_microarray_alt_missing = encode_entities($i18n ? $i18n->p('global.est.microarray_alt_missing', 'No alternative clones from any current unigene containing this EST are available on a microarray') : 'No alternative clones from any current unigene containing this EST are available on a microarray');
my $est_i18n_map_missing = encode_entities($i18n ? $i18n->p('global.est.map_missing', 'There is no map position defined on SGN for this EST or others in the same unigene.') : 'There is no map position defined on SGN for this EST or others in the same unigene.');
my $est_i18n_no_current_build = encode_entities($i18n ? $i18n->p('global.est.no_current_build', 'No current unigene builds incorporate this sequence') : 'No current unigene builds incorporate this sequence');
my %current_unigene = ();
my %previous_unigene = ();

our ($auto_idq, $request_typeq, $cloneq, $clone_read_idq,
    $clone_groupq, $alt_readq, $arrayq, $readq, $estq, $unigeneq,
    $by_clone_idq, $by_read_idq, $mspot_cloneq, $mid_cloneq, $table,
    $h_cgq, $h_cq, $h_traceq, $h_estq, $h_unigeneq, $randomq,
    $max_estid, $blastq, $microarray_byunigeneq, $try_clone_groupq,
    $marker_mappingq, $mapped_memberq, $trace_nameq, $clone_nameq,
    @known_request_from_types);


our $page = CXGN::Page->new( encode_entities(($i18n ? $i18n->p("global.final_caption.sgn_est_search_result", "SGN EST Search Result") : "SGN EST Search Result")), "Koni");

my $dbh = CXGN::DB::Connection->new;

$auto_idq = $dbh->prepare_cached("SELECT internal_id, internal_id_type, t1.comment, t2.comment from id_linkage as il LEFT OUTER JOIN types as t1 ON (t1.type_id=il.internal_id_type) LEFT OUTER JOIN types as t2 ON (t2.type_id=il.link_id_type) where il.link_id=?");

$request_typeq = $dbh->prepare_cached("SELECT comment from types where type_id=?");

$cloneq = $dbh->prepare_cached("SELECT c.clone_name, c.clone_group_id, l.library_shortname, l.tissue, l.development_stage, l.order_routing_id, o.organism_id, o.organism_name from clone as c, library as l, organism as o where c.clone_id=? and c.library_id=l.library_id and l.organism_id=o.organism_id");

$clone_read_idq = $dbh->prepare_cached(<<EOS);
SELECT	r.clone_id,
	e.read_id
FROM	seqread as r,
	est as e
WHERE e.est_id=?
  AND e.read_id=r.read_id
EOS

$try_clone_groupq = $dbh->prepare_cached("SELECT c2.clone_id, c2.clone_name from clone as c1 LEFT JOIN clone as c2 ON (c1.clone_group_id=c2.clone_group_id) where c1.clone_id=?");

$clone_groupq = $dbh->prepare_cached("SELECT clone_id, clone_name from clone where clone_group_id=?");

$alt_readq = $dbh->prepare_cached("SELECT clone.clone_name, seqread.read_id, direction, facility_shortname, est_id from clone LEFT JOIN seqread USING (clone_id) LEFT JOIN facility USING (facility_id) LEFT JOIN est ON (seqread.read_id=est.read_id) where clone.clone_id=? and (est.status=0 and est.flags=0)");

$arrayq = $dbh->prepare_cached("SELECT chip_name, version, release, spot_id from microarray where clone_id=?");

$readq = $dbh->prepare_cached("SELECT r.trace_name, r.direction, f.facility_shortname, f.funding_agency, f.attribution_display, s.name from seqread as r  LEFT OUTER JOIN facility as f USING (facility_id) LEFT OUTER JOIN clone ON (r.clone_id=clone.clone_id) LEFT OUTER JOIN library USING (library_id) LEFT OUTER JOIN submit_user as s ON (library.submit_user_id=s.submit_user_id) where r.read_id=?");

$estq = $dbh->prepare_cached("SELECT est.basecaller, version, seq, status, flags, hqi_start, hqi_length, entropy, expected_error, quality_trim_threshold, vs_status from est LEFT JOIN qc_report USING (est_id) where est.est_id=?");

$unigeneq = $dbh->prepare_cached(<<EOS);
SELECT 	unigene_member.unigene_id,
	unigene_build.unigene_build_id,
       	groups.comment,
	build_nr,
	build_date,
	nr_members,
	est.est_id
FROM est LEFT JOIN unigene_member USING (est_id)
         LEFT JOIN unigene        USING (unigene_id)
         LEFT JOIN unigene_build  USING (unigene_build_id)
         LEFT JOIN groups         ON (organism_group_id=groups.group_id)
WHERE est.est_id=?
  AND unigene_build.status=?
EOS

$by_clone_idq = $dbh->prepare_cached("SELECT read_id, direction, facility_id, date from seqread where clone_id=?");

$by_read_idq = $dbh->prepare_cached("SELECT est_id, version from est where read_id=?");
$mspot_cloneq = $dbh->prepare_cached("SELECT clone_id from microarray where release=? and version=? and spot_id=?");
$mid_cloneq = $dbh->prepare_cached("SELECT clone_id from microarray where microarray_id=?");

$h_cgq = $dbh->prepare_cached("SELECT clone_group_id, clone_name
                        FROM clone where clone_id=?");

$h_cq = $dbh->prepare_cached("SELECT clone_id, clone_name from clone where clone_group_id=? and clone_id<>?");

$h_traceq = $dbh->prepare_cached("SELECT read_id, trace_name FROM seqread where
                              clone_id=?");
$h_estq = $dbh->prepare_cached("SELECT est_id, version FROM est where read_id=?");

$h_unigeneq = $dbh->prepare_cached(<<EOS);
SELECT 	unigene.unigene_id,
	unigene_build.build_nr,
	groups.comment
FROM unigene_member
LEFT JOIN unigene ON (unigene_member.unigene_id=unigene.unigene_id)
LEFT JOIN unigene_build ON (unigene.unigene_build_id=unigene_build.unigene_build_id)
LEFT JOIN groups ON (unigene_build.organism_group_id=groups.group_id)
WHERE unigene_member.est_id=?
  AND unigene_build.status IS NOT NULL
  AND unigene_build.status <> 'D'
EOS

$blastq = $dbh->prepare_cached("SELECT db_name, blast_program, hits_stored from blast_annotations LEFT JOIN blast_targets USING (blast_target_id) where apply_id=? and apply_type=15");

#$randomq = $dbh->prepare_cached("SELECT est_id from est where status=0 and flags=0 order by random() limit 1000");

$microarray_byunigeneq = $dbh->prepare_cached("select est.est_id from unigene LEFT JOIN unigene_member USING (unigene_id) LEFT JOIN est USING (est_id) LEFT JOIN seqread using (read_id) LEFT JOIN clone using (clone_id) INNER JOIN microarray using (clone_id) where unigene.unigene_id=? order by clone.clone_id");

$marker_mappingq = $dbh->prepare_cached("select marker_id, alias from marker_alias where marker_id in (select marker_id from marker_derived_from  where derived_from_source_id = 1 and id_in_source = ?) and preferred is true");

$mapped_memberq = $dbh->prepare_cached("select ests_mapped_by_clone.clone_id from unigene_member INNER JOIN est USING (est_id) INNER JOIN seqread USING (read_id) INNER JOIN ests_mapped_by_clone USING (clone_id) where unigene_id=?");

$trace_nameq = $dbh->prepare_cached("select read_id from seqread where trace_name=?");

$clone_nameq = $dbh->prepare_cached("select clone_id from clone where clone_name=?");

@known_request_from_types = ( "web user", "SGN database generated link", "SGN BLAST generated link","Random Selection" );

# This is used commonly when building the HTML below, saves having to
# type (or read) these commonly desired settings
$table = 'table cellspacing="0" cellpadding="0" border="0" width="100%"';

my ($request_id, $request_type, $request_from, $show_hierarchy, $random) =
  $page->get_arguments("request_id","request_type","request_from",
		       "show_hierarchy","random");

$request_id = sanitize_string($request_id);
$request_type = sanitize_string($request_type);
$request_from = sanitize_string($request_from);
$show_hierarchy = sanitize_string($show_hierarchy);
$random = sanitize_string($random);



# If the identifier is not given, or the identifier parameter is
# screwed up, we want to give the right error instead of failing
# later on for an unrelated reason.
$page->message_page(encode_entities($i18n ? $i18n->p("global.est.no_est_identifier", "No EST identifier specified") : "No EST identifier specified")) unless $request_id || ($random eq 'yes');


if ($random eq "yes") {
  $request_type=7;
  $request_from=3;
  ($request_id) = $dbh->selectrow_array("select est_id from est where status=0 and flags=0 order by random() limit 1");

}

if ($request_id eq "" || $request_type eq "") {
  if ($request_from==1 || $request_from==2) {
    $page->error_page("Invalid Direct Search from SGN-generated URL. Requested \"$request_id\" set type \"$request_type\"");
  } else {
    invalid_search($page);
  }
}

if ($request_from<0 || $request_from>$#known_request_from_types) {
  $request_from = "external (unknown - unsupported)";
} else {
  $request_from = $known_request_from_types[$request_from];
}

my ($id, $id_type) = ($request_id, $request_type);



# If a user-entered generic identifier has been entered, take it to the
# id linkage table for resolution to an SGN internal identifier and type
my ($id_type_name, $link_id_type_name);
if ($id_type eq "automatic") {

  # Check for internal types. These will not be in the id_linkage table
  if ($id =~ m/^SGN[|-]C([0-9]+)$/i) {
    $id_type = 8;
    $id_type_name = "SGN Clone Identifier";
    $id = $1;
  } elsif ($id =~ m/^SGN[|-]T([0-9]+)$/i) {
    $id_type = 9;
    $id_type_name = "SGN Chromatogram Identifer";
    $id = $1;
  } elsif ($id =~ m/^SGN[|-]E([0-9]+)$/i) {
    $id_type = 7;
    $id_type_name = "SGN EST Identifier";
    $id = $1;
  } else {
    # OK, try the id_linkage table then
    if ($request_id =~ m/^([A-Z]{3,4})([0-9]+)([A-P][0-9]{1,2})$/i) {
      $request_id = "$1-$2-$3";
    }
    $auto_idq->execute($request_id);
    if ($auto_idq->rows == 0) {
      not_found($page, encode_entities($i18n ? $i18n->p("global.est.identifier_not_found", "Identifier \"%{id}\" was not found in SGN's databases.", { id => $id }) : "Identifier \"$id\" was not found in SGN's databases."));
    }

    if ($auto_idq->rows > 1) {
      ($id) = $auto_idq->fetchrow_array();
      show_list($page, $id);
    }

    ($id, $id_type, $id_type_name, $link_id_type_name) =
      $auto_idq->fetchrow_array();
  }
} else {
  if ($id_type =~ m/\d+/) {
    $request_typeq->execute($id_type);
    ($id_type_name) = $request_typeq->fetchrow_array();
  }
}


# Resolve to an EST identifier, either the internal id found above,
# or the direct reference from an SGN-generated link
my $est_id = "";
my $match_id = "";
if ($id_type == 7) {
  # This is an EST identifier already
  invalid_search($page, encode_entities($i18n ? $i18n->p("global.est.invalid_est_id", "Invalid identifier \"%{id}\" for specified identifier type (SGN-E#)", { id => $id }) : "Invalid identifier \"$id\" for specified identifier type (SGN-E#)")) if ($id !~ m/^(SGN-E|E|)([0-9]+)$/);
  $match_id = "SGN-E$2";
  $est_id = $2;

} elsif ($id_type == 8) {
  invalid_search($page, encode_entities($i18n ? $i18n->p("global.est.invalid_clone_id", "Invalid identifier \"%{id}\" for specified identifier type (SGN-C#)", { id => $id }) : "Invalid identifier \"$id\" for specified identifier type (SGN-C#)")) if ($id !~ m/^(SGN-C|C|)([0-9]+)$/);
  # This is a clone internal identifier - find a trace, then find an EST
  if ($show_hierarchy) {
    hierarchy_requested($page, $id, $id_type);
  }
  $match_id = "SGN-C$2";
  $est_id = by_clone($page, $2);
} elsif ($id_type == 9) {
  # This is a trace identifier, find the most recent sequence for it
  invalid_search($page, encode_entities($i18n ? $i18n->p("global.est.invalid_trace_id", "Invalid identifier \"%{id}\" for specified identifier type (SGN-T#)", { id => $id }) : "Invalid identifier \"$id\" for specified identifier type (SGN-T#)")) if ($id !~ m/^(SGN-T|T|)([0-9]+)$/);
  $match_id = "SGN-T$2";
  $est_id = by_read($page, $2);
} elsif ($id_type == 10) {
  if ($request_id =~ m/^([A-Z]{3,4})([0-9]+)([A-P][0-9]{1,2})$/i) {
    $request_id = "$1-$2-$3";
  }
  $clone_nameq->execute($request_id);
  if ($clone_nameq->rows == 0) {
    not_found($page, "Identifier \"$request_id\" was not found in SGN's databases.");
  }
  ($match_id) = $clone_nameq->fetchrow_array();
  $est_id = by_clone($page, $match_id);
} elsif ($id_type == 11) {
  $trace_nameq->execute($request_id);
  if ($trace_nameq->rows == 0) {
    not_found($page, "Identifier \"$request_id\" was not found in SGN's databases.");
  }
  ($match_id) = $trace_nameq->fetchrow_array();
  $est_id = by_read($page, $match_id);
} elsif ($id_type == 14) {
  # This is a microarray identifier.
  invalid_search($page, "Invalid identifier \"$id\" for specified identifier type (SGN/CGEP/TMD Microarray Spot Identifier)") if ($id !~ m/^(SGN-S|S|)([0-9]+-[0-9]+-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/);
  $match_id = "SGN-S$2";
  $est_id = by_mspot($page, $2);
}

# This is an EST search result page, we must now have an internal EST
# identifier (est_id in table est) to continue
if ($est_id eq "") {
  not_traceable_to_est($page, $request_id, $id, $id_type);
}

# Now that we have an EST identifier, try to find a chromatogram that
# it is linked to, and a clone that is linked to that chromatogram.

# NOTE: This step may go backwards (unnecessarily) from the above
# Fetch out the clone_id and read_id for this EST.
my ($clone_id, $read_id);
$clone_read_idq->execute($est_id);
($clone_id, $read_id) = $clone_read_idq->fetchrow_array();

# Section containing information on what was searched for and what was found
my $search_info = <<EOF;
<$table>
<tr><td width="50%"><b>$est_i18n_request</b> $request_id</td><td><b>$est_i18n_match</b> $match_id</td></tr>
<tr><td><b>$est_i18n_request_from</b> $request_from</td><td><b>$est_i18n_match_type</b> $id_type_name</td></tr>
</table>
EOF


# Look up clone info and library information
my $clone_info = "";
my $clone_name = "";
my @clone_group = ();

my $organism_id = "";
if ($clone_id ne "" && $cloneq->execute($clone_id) && $cloneq->rows>0) {
  my ($clone_name, $clone_group_id, $library_name, $tissue,
   $development_stage, $order_routing_id, $organism_id, $organism_name) =
     $cloneq->fetchrow_array();

  # If there are nulls in the table we'll get undefs for these values, so we
  # set displayed values here.
  $organism_name = $est_i18n_unknown if !defined($organism_name);
  $tissue = $est_i18n_unknown if !defined($tissue);

  # If we have a clone group, seek out the replicate clone_ids so we can
  # search them below for alternative reads
  if ($clone_group_id) {
    $clone_groupq->execute($clone_group_id);
    while(my ($cid, $cname) = $clone_groupq->fetchrow_array()) {
      push @clone_group, [ $cid, $cname ];
    }
  } else {
    # If there is no clone group in the database, make a fake singleton
    # group here for ease below
    @clone_group = ([ $clone_id, $clone_name ]);
  }

  # Microarray Information
  my $microarray = "";
  if ($organism_id == 1 || $organism_id == 2 || $organism_id == 3) {
    foreach ( @clone_group ) {
      $arrayq->execute($_->[0]);
      my ($chip_name, $version, $release, $spot_id);
      while (($chip_name, $version, $release, $spot_id) =
	     $arrayq->fetchrow_array) {
	if ($_->[0] != $clone_id) {
	  $microarray .= $render_i18n_html->(($i18n ? $i18n->p("global.est_detail.alias_microarray", "Alias clone %{link} is on microarray %{chip}: SGN-S%{spot}\n", {link => "__SGN_UI_LINK__", chip => "__SGN_UI_CHIP__", spot => "__SGN_UI_SPOT__"}) : "Alias clone __SGN_UI_LINK__ is on microarray __SGN_UI_CHIP__: SGN-S__SGN_UI_SPOT__\n"), {"__SGN_UI_LINK__" => '<a href="/search/est.pl?request_id=' . $_->[0] . '&request_type=8&request_from=1">SGN-C' . $_->[0] . '</a>', "__SGN_UI_CHIP__" => encode_entities($chip_name), "__SGN_UI_SPOT__" => encode_entities("$version-$release-$spot_id")});
	} else {
	  $microarray .= $render_i18n_html->(($i18n ? $i18n->p("global.est_detail.microarray_spot", "SGN-C%{clone} is on microarray %{chip} spot ID %{spot} [%{order}] [%{database}]\n", {clone => "__SGN_UI_CLONE__", chip => "__SGN_UI_CHIP__", spot => "__SGN_UI_SPOT__", order => "__SGN_UI_ORDER__", database => "__SGN_UI_DATABASE__"}) : "SGN-C__SGN_UI_CLONE__ is on microarray __SGN_UI_CHIP__ spot ID __SGN_UI_SPOT__ [__SGN_UI_ORDER__] [__SGN_UI_DATABASE__]\n"), {"__SGN_UI_CLONE__" => $_->[0], "__SGN_UI_CHIP__" => encode_entities($chip_name), "__SGN_UI_SPOT__" => encode_entities("$version-$release-$spot_id"), "__SGN_UI_ORDER__" => '<a href="http://bti.cornell.edu/CGEP/CGEP.html">' . $est_i18n_order . '</a>', "__SGN_UI_DATABASE__" => '<a href="http://ted.bti.cornell.edu/cgi-bin/array/basicsearch.cgi?arrayID=' . "$version-$release-$spot_id" . '">Tomato Microarray Database</a>'});
	}
      }
    }
    $microarray ||= '<span class="ghosted">' . $est_i18n_microarray_missing . '</span>';
    $microarray = "<b>$est_i18n_microarray</b> $microarray<br />";
  }

  my $ordering;
  if ($order_routing_id) {
    $ordering = qq{<table cellpadding="1" cellspacing="0" border="0"><tr><td><a href="/search/clone-order.pl?add_clone=$clone_name"><img src="/documents/img/sgn-cart.gif" border="0" alt="cart" /></a></td><td>$est_i18n_order_clone</td></tr></table>};
  } else {
    $ordering = qq{<table cellpadding="1" cellspacing="0" border="0"><tr><td><img src="/documents/img/sgn-nocart.gif" border="0" alt="nocart" /></td><td><span class="ghosted">$est_i18n_ordering_not_available</span></td></tr></table>};
  }

# Section with information about the selected clone
# Note: The closing table & outer table cell/row tags are omitted here, because
#       "the group" requested that the EST search result page show whether or
#       not a current unigene contains a microarray'd clone. This query
#       is not possible until we get the unigene section, so we'll have some
#       more things to add to the Clone section later.
#
#       So much for organizing the script into little sections.
  $clone_info = <<EOF;
    <$table>
    <tr><td width="40%"><b>$est_i18n_sgn_id</b> SGN-C$clone_id</td><td><b>$est_i18n_clone_name</b> $clone_name</td><td width="20%" rowspan="2">$ordering</td></tr>
    <tr><td><b>$est_i18n_library_name</b> $library_name</td><td><b>$est_i18n_organism</b> $organism_name</td></tr>
    </table>
    <br />
    <b>$est_i18n_tissue</b> $tissue<br />
    <b>$est_i18n_development_stage</b> $development_stage<br />
    <br />
    $microarray
EOF

} else {
  # no clone information was found
  $clone_info = '<div><span class="ghosted">' . $est_i18n_no_clone_info . '</span></div>';
  $clone_name = encode_entities($i18n ? $i18n->p('global.est.clone_name_unknown', 'clone name unknown') : 'clone name unknown');
}

# Search for information on the chromatogram
my $read_info = "";
my $seqdir = "";
if ($read_id && $readq->execute($read_id) && $readq->rows>0) {
  $readq->execute($read_id);

  my ($chroma_name, $facility_name, $submitter_name, $funding_agency,
   $atb_organization, $atb_display);
  ($chroma_name, $seqdir, $facility_name, $atb_organization, $atb_display,
   $submitter_name) = $readq->fetchrow_array();

  if (!defined($seqdir)) {
    $seqdir = $est_i18n_unknown;
  } elsif ($seqdir eq "5") {
    $seqdir = "5'";
  } elsif ($seqdir eq "3") {
    $seqdir = "3'";
  } else {
    $seqdir = $est_i18n_unknown;
  }

  $submitter_name = '<span class="ghosted">' . encode_entities($i18n ? $i18n->p('global.est.none', 'None') : 'None') . '</span>' unless $submitter_name;
  $atb_display ||= $atb_organization;
  if ($atb_display) {
    $atb_display = "<b>$est_i18n_funding_organization</b>&nbsp;$atb_display";
  }

  my $view_link='[<span class="ghosted">' . $est_i18n_view . '</span>]';
#  my $view_link=" [<a href=\"/tools/trace_view.pl?read_id=$read_id&est_id=$est_id\">$est_i18n_view</a>]";
  my $tmp_tracename;
  if($tmp_tracename=CXGN::Chromatogram::has_abi_chromatogram($read_id))
  {
      my $path_to_remove = $c->path_to( $c->tempfiles_subdir('traceimages') );
      $tmp_tracename=~s/$path_to_remove//;
      my $file=URI::Escape::uri_escape("$tmp_tracename");
      $view_link=" [<a href=\"/tools/trace_view.pl?file=$file&temp=yes\">$est_i18n_view</a>]";
  }

  $read_info = <<EOF;
    <$table>
      <tr><td width="50%"><b>$est_i18n_sgn_trace_id</b> SGN-T$read_id [<a href="/search/trace_download.pl?read_id=$read_id">$est_i18n_download</a>]$view_link</td>
          <td><b>$est_i18n_facility_assigned_id</b> $chroma_name\n</td>
      </tr>
      <tr><td><b>$est_i18n_submitter</b> $submitter_name</td>
          <td><b>$est_i18n_sequencing_facility</b> $facility_name</td>
      </tr>
    </table>

  $atb_display
EOF
} else {
  $read_info='<span class="ghosted">' . $est_i18n_no_chromatogram . '</span>';
}

# Find alternate reads for this clone group
my $alt_reads = "";
my $see_also = "";
foreach ( @clone_group ) {
  $alt_readq->execute($_->[0]);
  my ($clone_name, $trace_id, $dir, $facility, $eid);
  while(($clone_name, $trace_id, $dir, $facility, $eid)
	= $alt_readq->fetchrow_array()) {
    next if $eid==$est_id;
    if (!defined($dir)) {
      $dir = "Unknown";
    } elsif ($dir eq "5") {
      $dir = "5'";
    } elsif ($dir eq "3") {
      $dir = "3'";
    } else {
      $dir = "Unknown";
    }

    # This is hacked in here as an after thought, to draw the viewer's
    # attention to the additional sequencing section.
    if ($seqdir eq "5'" && $dir eq "3'") {
      $see_also = '[' . encode_entities($i18n ? $i18n->p("global.est.see_three_prime_reads", "See links to 3' reads above") : "See links to 3' reads above") . ']';
    } elsif ($seqdir eq "3'" && $dir eq "5'") {
      $see_also = '[' . encode_entities($i18n ? $i18n->p("global.est.see_five_prime_reads", "See links to 5' reads above") : "See links to 5' reads above") . ']';
    }

    $facility = $est_i18n_unknown if !defined($facility);
    $alt_reads .= <<EOF
      <tr><td><b>$est_i18n_clone</b> SGN-C$_->[0] [$clone_name]</td>
	  <td><b>$est_i18n_trace</b> SGN-T$trace_id</td>
	  <td><b>$est_i18n_est</b> <a href="/search/est.pl?request_id=$eid&amp;request_type=7&amp;request_from=1">SGN-E$eid</a></td>
	  <td><b>$est_i18n_direction</b> $dir</td>
	  <td><b>$est_i18n_facility</b> $facility</td>
      </tr>
EOF
  }
}
if($alt_reads) {
  $alt_reads = "<table>$alt_reads</table>" ;
} else {
  $alt_reads = '<span class="ghosted">' . $est_i18n_no_additional_reads . '</span>';
}


$estq->execute($est_id);
if ($estq->rows == 0) {
  not_found($page, encode_entities($i18n ? $i18n->p("global.est.no_est_database_entry", "No database entry was found for EST identifier SGN-E%{id}", { id => $est_id }) : "No database entry was found for EST identifier SGN-E$est_id"));
}
my ($basecaller,$version,$seq,$status,$flags,$start,$length,$entropy,$expected_error,$qtrim_threshold,$vs_status) = $estq->fetchrow_array();

my $fasta_header;
my $seq_display = "";
my $untrim_length = length($seq);
my $seq_length;
if (defined($start) && defined($length) && ($length > 10) ) {
  if ($flags) {
    $fasta_header = "&gt;SGN-E$est_id [$clone_name]  (trimmed - flagged)";
  } else {
    $fasta_header = "&gt;SGN-E$est_id [$clone_name]  (trimmed)";
  }
  $seq = substr $seq,$start,$length;
  $seq_length = qq|${length} bp <span class="ghosted">(${untrim_length} bp untrimmed)</span>|;
} else {
  if ($status & 0x1) {
    $fasta_header = ">SGN-E$est_id [$clone_name] (called/trimmed by facility)<br />";
    $seq_length = "${untrim_length} bp (called/trimmed by facility)<br />";
  } else {
    $fasta_header = ">SGN-E$est_id [$clone_name] (untrimmed)<br />";
    $seq_length = qq{<span class="ghosted">${untrim_length} bp (untrimmed)</span>};
  }
}


$seq_display = html_break_string($seq,95);

my $display_status = "";
if ($status == 0) {
  $display_status = encode_entities($i18n ? $i18n->p("global.est.status_current", "Current Version") : "Current Version");
}
if ($status & 0x1) {
  $display_status .= encode_entities($i18n ? $i18n->p("global.est.status_legacy", "Legacy ") : "Legacy ");
}
if ($status & 0x2) {
  $display_status .= encode_entities($i18n ? $i18n->p("global.est.status_discarded", "Discarded ") : "Discarded ");
}
if ($status & 0x4) {
  $display_status .= encode_entities($i18n ? $i18n->p("global.est.status_deprecated", "Deprecated ") : "Deprecated ");
}
if ($status & 0x8) {
  $display_status .= encode_entities($i18n ? $i18n->p("global.est.status_censored", "Censored ") : "Censored ");
}
if ($status & 0x10) {
  $display_status .= encode_entities($i18n ? $i18n->p("global.est.status_trim_not_applied", "Vector/Quality trimming not applied ") : "Vector/Quality trimming not applied ");
}
if ($status & 0x20) {
  $display_status .= encode_entities($i18n ? $i18n->p("global.est.status_contaminants_not_assessed", "Contaminants not assessed ") : "Contaminants not assessed ");
}
if ($status & 0x40) {
  $display_status .= encode_entities($i18n ? $i18n->p("global.est.status_chimera_not_assessed", "Chimera not assessed ") : "Chimera not assessed ");
}

my $insert_recovery = "";
my $vector_signature = "";
if (!($status & 0x11)) {
  $expected_error = sprintf "%7.4f",$expected_error;
  $entropy = sprintf "%5.3f",$entropy;


  my @vector_sig_strings =
    (encode_entities($i18n ? $i18n->p("global.est.vector_read_5", "5' sequence read -- flanking 3' vector arm detected.") : "5' sequence read -- flanking 3' vector arm detected."),
     encode_entities($i18n ? $i18n->p("global.est.vector_read_3", "3' sequence read -- flanking 5' vector arm detected.") : "3' sequence read -- flanking 5' vector arm detected."),
     encode_entities($i18n ? $i18n->p("global.est.vector_read_5_incomplete", "5' sequence read, incomplete (flanking vector not found)") : "5' sequence read, incomplete (flanking vector not found)"),
     encode_entities($i18n ? $i18n->p("global.est.vector_read_3_incomplete", "3' sequence read, incomplete (flanking vector not found)") : "3' sequence read, incomplete (flanking vector not found)"),
     #make these red and bold
     (map {'<span style="color: red; font-weight: bold;">'.$_.'</span>'}
      (encode_entities($i18n ? $i18n->p("global.est.vector_missing", "No vector sequence detected") : "No vector sequence detected"),
       encode_entities($i18n ? $i18n->p("global.est.vector_pattern_inconsistent", "Vector found but pattern inconsistent with a normal insert") : "Vector found but pattern inconsistent with a normal insert"),
       encode_entities($i18n ? $i18n->p("global.est.multiple_cloning_site", "Multiple cloning site sequence detected -- chimeric clone suspected.") : "Multiple cloning site sequence detected -- chimeric clone suspected."),
      )
     ),
    );

  $vector_signature = $vector_sig_strings[$vs_status]
    || '<span class="ghosted">' . encode_entities($i18n ? $i18n->p("global.est.not_available", "Not available") : "Not available") . '</span>';


  ### render any flags as html
  my @flag_strings = (
      encode_entities($i18n ? $i18n->p("global.est.vector_anomaly", "Vector anomaly") : "Vector anomaly"),
      encode_entities($i18n ? $i18n->p("global.est.possibly_chimeric_vector", "Possibly chimeric (anomalous insert into vector)") : "Possibly chimeric (anomalous insert into vector)"),
      encode_entities($i18n ? $i18n->p("global.est.too_short_after_trimming", "Too short after trimming low-quality bases") : "Too short after trimming low-quality bases"),
      encode_entities($i18n ? $i18n->p("global.est.high_expected_error", "High expected error (low overall quality)") : "High expected error (low overall quality)"),
      encode_entities($i18n ? $i18n->p("global.est.low_complexity", "Low complexity") : "Low complexity"),
      encode_entities($i18n ? $i18n->p("global.est.ecoli_sequence", "E. Coli (cloning host) sequence detected") : "E. Coli (cloning host) sequence detected"),
      encode_entities($i18n ? $i18n->p("global.est.rrna_contamination", "rRNA contamination detected") : "rRNA contamination detected"),
      encode_entities($i18n ? $i18n->p("global.est.possibly_chimeric_arabidopsis", "Possibly chimeric (ends match significantly different genes in arabidopsis)") : "Possibly chimeric (ends match significantly different genes in arabidopsis)"),
      encode_entities($i18n ? $i18n->p("global.est.possibly_chimeric_preclustering", "Possibly chimeric, detected by unigene assembly preclustering") : "Possibly chimeric, detected by unigene assembly preclustering"),
      encode_entities($i18n ? $i18n->p("global.est.manually_censored", "Manually censored by SGN staff") : "Manually censored by SGN staff"));

  my $flags_display = "";
  if ($flags == 0) {
    $flags_display = encode_entities($i18n ? $i18n->p("global.est.passed_screens", "Passed all screens and filters") : "Passed all screens and filters");
  } else {
    my @flags = ();

    my $ind = 0;
    foreach my $str (@flag_strings) {
      push @flags,$str if $flags & (1<<$ind++);
    }

    $flags_display = qq{<$table><tr><td width="10%"><b>$est_i18n_problems </b></td><td>} . join("<br />",@flags) . "</td></tr></table>";
  }

  $insert_recovery= <<EOF;
<$table><tr><td width="50%"><b>$est_i18n_processed_by</b> SGN</td>
            <td><b>$est_i18n_basecalling</b> phred</td>
       </tr>
</table>
<b>$est_i18n_vector_signature</b> $vector_signature<br />
$flags_display
<table cellspacing="0" cellpadding="0" border="0" width="90%" align="center">
  <tr><td><b>$est_i18n_sequence_entropy</b> $entropy</td>
      <td><b>$est_i18n_expected_error</b> $expected_error</td>
      <td><b>$est_i18n_quality_trim</b> $qtrim_threshold</td>
  </tr>
</table>
EOF
} else {
  $insert_recovery = '<span class="ghosted">' . encode_entities($i18n ? $i18n->p("global.est.processing_info_unavailable", "Processing information not available for this sequence") : "Processing information not available for this sequence") . '</span>';
}

my $sequence_info = <<END_HTML;
  <$table>
  <tr><td width="50%"><b>$est_i18n_sequence_id</b> SGN-E$est_id</td><td><b>$est_i18n_length</b> $seq_length</td></tr>
  <tr><td><b>$est_i18n_status</b> $display_status</td><td><b>$est_i18n_direction</b> $seqdir $see_also</td></tr>
  </table>
  <div class="sequence" style="margin: 1em">
        $fasta_header
        $seq_display
  </div>
  <center>
  [<a href="/tools/blast/?preload_id=$est_id&amp;preload_type=7">BLAST</a>]&nbsp;&nbsp;[<a href="/tools/sixframe_translate.pl?est_id=$est_id">AA Translate</a>]
  </center>
END_HTML

my $unigene_content;
my $other_estid = "";
my $alt_microarray = "";
my $alt_mapped = "";
my @recent = ();
$unigeneq->execute($est_id, "C");
while(my ($unigene_id, $build_id, $og_name, $build_nr, $build_date,
	  $nr_members, $eid) = $unigeneq->fetchrow_array()) {
  # Used to indicate below that we have pulled up unigenes from other ESTs
  # that are from the same chromatogram
  $other_estid = $eid if ($eid != $est_id);


#  unless(defined($organism_id)) {$organism_id=0;}
  unless($organism_id) {$organism_id=0;}

  if ($organism_id == 1 || $organism_id == 2 || $organism_id == 3) {
    $microarray_byunigeneq->execute($unigene_id);
    if ($microarray_byunigeneq->rows > 0) {
      my $alt_microarray_found = 0;
      while(my ($eid) = $microarray_byunigeneq->fetchrow_array()) {
	next if ($eid == $est_id);
	$alt_microarray_found = 1;
	last;
      }
      if ($alt_microarray_found) {
        my $unigene_link_html = '<a href="/search/unigene.pl?unigene_id=' . $unigene_id . '">' . encode_entities("SGN-U$unigene_id") . '</a>';
        my $alternative_message = $render_i18n_html->(($i18n ? $i18n->p("global.est.microarray_alternatives", "See unigene %{link} for alternatives which are available on a microarray", {link => "__SGN_UI_LINK__"}) : "See unigene __SGN_UI_LINK__ for alternatives which are available on a microarray"), {"__SGN_UI_LINK__" => $unigene_link_html});
	$alt_microarray .= $alternative_message . '<br />';
      }
    }
  }

  $marker_mappingq->execute($clone_id);
  if ($marker_mappingq->rows > 0) {
    while (my ($marker_id, $alias) = $marker_mappingq->fetchrow_array()){
      my $marker_link_html = '<a href="/search/markers/markerinfo.pl?marker_id=' . $marker_id . '">' . encode_entities($alias) . '</a>';
      my $mapped_message = $render_i18n_html->(($i18n ? $i18n->p("global.est.clone_mapped_as", "This clone has been mapped as %{link}.", {link => "__SGN_UI_LINK__"}) : "This clone has been mapped as __SGN_UI_LINK__."), {"__SGN_UI_LINK__" => $marker_link_html});
      $alt_mapped .= $mapped_message . '<br />';
    }
  } else {
    $mapped_memberq->execute($unigene_id);
    if ($mapped_memberq->rows > 0) {
      my $alt_mapped_found = 0;
      while (my ($cid) = $mapped_memberq->fetchrow_array()) {
	next if ($cid == $clone_id);
	$alt_mapped_found = 1;
      }
      if ($alt_mapped_found) {
        my $unigene_link_html = '<a href="/search/unigene.pl?unigene_id=' . $unigene_id . '">' . encode_entities("SGN-U$unigene_id") . '</a>';
        $alt_mapped .= $render_i18n_html->(($i18n ? $i18n->p("global.est.alternative_clones_mapped", "See unigene %{link} for alternative clones/ESTs which are mapped", {link => "__SGN_UI_LINK__"}) : "See unigene __SGN_UI_LINK__ for alternative clones/ESTs which are mapped"), {"__SGN_UI_LINK__" => $unigene_link_html});
      }
    }
  }
  my $recent_build_caption = encode_entities(($i18n ? $i18n->p("global.est_detail.build_number", "Build %{number}", {number => $build_nr}) : "Build $build_nr"));
  my $recent_est_count = encode_entities(($i18n ? $i18n->p("global.est_detail.ests_assembled", "%{count} ESTs assembled", {count => $nr_members}) : "$nr_members ESTs assembled"));
  push @recent, <<EOF;
  <tr><td>[SGN-E$eid]  </td>
      <td><a href="/search/unigene.pl?unigene_id=$unigene_id&amp;highlight=$eid">SGN-U$unigene_id</a></td>
      <td>$og_name        </td>
      <td>$recent_build_caption </td>
      <td>$recent_est_count</td>
  </tr>
EOF
}

if (!$alt_microarray &&
    ($organism_id == 1 || $organism_id == 2 || $organism_id == 3)) {
  $alt_microarray = '<span class="ghosted">' . $est_i18n_microarray_alt_missing . '</span>';
}

$alt_mapped ||= "<div><span class=\"ghosted\">$est_i18n_map_missing</span></div>";



$unigene_content = '<table align="center" cellspacing="0" cellpadding="0" border="0" width="100%">';

if ($other_estid) {
  my $unigene_version_note = encode_entities($i18n ? $i18n->p("global.est.unigene_version_note", "Note: Some unigenes listed here are assembled from different versions of the sequence displayed above. Note SGN-E# in left column. All versions were derived from the same chromatogram") : "Note: Some unigenes listed here are assembled from different versions of the sequence displayed above. Note SGN-E# in left column. All versions were derived from the same chromatogram");
  $unigene_content .= qq{<tr><td colspan="6"><span class="ghosted">$unigene_version_note</span></td></tr><tr><td colspan="6"><br /></td></tr>};
}

if (@recent) {
  $unigene_content .= <<EOF;
<tr><td colspan="6"><b>$est_i18n_current_builds</b></td></tr>
@recent
<tr><td colspan="6" align="center"><span class="ghosted">$est_i18n_follow_unigene</span></td></tr>
EOF
} else {
  $unigene_content .= <<EOF;
<tr><td align="left" colspan="6"><b>$est_i18n_current_builds</b></td></tr>
<tr><td colspan="6"><span class="ghosted">$est_i18n_no_current_build</td></tr>
EOF
}

$unigene_content .= "</table>";


$page->header();
my $est_page_title = $i18n ? $i18n->p('global.est.page_title', 'EST details &mdash; %{id}', { id => encode_entities($match_id) }) : "EST details &mdash; $match_id";
print page_title_html($est_page_title);
print blue_section_html($est_i18n_search_info,$search_info);
print blue_section_html($est_i18n_clone_info,<<EOH);
$clone_info
$alt_microarray
$alt_mapped
EOH
$alt_reads .= qq{<center style="margin-top: 0.8em"><a href="/search/est.pl?request_id=$clone_id&amp;request_type=8&amp;request_from=1&amp;show_hierarchy=1">$est_i18n_show_hierarchy</a></center>};
print blue_section_html($est_i18n_additional_sequencing,$alt_reads);
print blue_section_html($est_i18n_sequence,$sequence_info);
print blue_section_html($est_i18n_unigenes,$unigene_content);
print blue_section_html($est_i18n_chromatogram,$read_info);
print blue_section_html($est_i18n_quality_processing,$insert_recovery);

$page->footer();

sub by_clone {

  my ($page, $id) = @_;

  my $read_id = "";
  $by_clone_idq->execute($id);
  if ($by_clone_idq->rows == 0) {
    $try_clone_groupq->execute($id);
    if ($try_clone_groupq->rows > 1) {
      try_clone_group($page, $id);
    }
    not_found($page, "Your search resolved to a clone identifier (SGN-C$id) that was not found in SGN's databases. No alias clones were found.");
  } elsif ($by_clone_idq->rows == 1) {
    ($read_id) = $by_clone_idq->fetchrow_array();
  } else {
    my @reads = sort by_clone_sort @{$by_clone_idq->fetchall_arrayref()};
    ($read_id) = $reads[0]->[0];
  }

  return by_read($page, $read_id);
}

# Hard coded layout here, as well as codes for facility ids.
sub by_clone_sort {

  if ($a->[1] ne $b->[1]) {
    # Promotes 5' over 3' reads
    return -1 if $a->[1] eq "5";
    return 1;
  }
  if ($a->[2] != $b->[2]) {
    # Promotes TIGR and Genoscope facilities, but ignores the rest
    return -1 if $a->[2] == 1;
    return 1 if $b->[2] == 1;
    return -1 if $a->[2] == 4;
    return 1 if $b->[2] == 4;
  }
  # Lastly, sort by submission date
  return $b->[2] - $a->[2];
}

sub by_read {

  my ($page, $id) = @_;

  $by_read_idq->execute($id);

  if ($by_read_idq->rows == 0) {
    not_found($page, "Your search resolved to a trace identifier (SGN-T$id) that was not found in SGN's databases");
  } elsif ($by_read_idq->rows == 1) {
    my ($est_id) = $by_read_idq->fetchrow_array();
    return $est_id;
  }

  my @ests = sort by_read_sort @{$by_read_idq->fetchall_arrayref()};
  return $ests[0]->[0];
}

sub by_read_sort {
  # Sort by version
  if ($a->[1] != $b->[1]) {
    return $b->[1] - $a->[1];
  }
  # Default to identifier sort if necessary
  return $b->[0] - $a->[0];
}

sub by_mspot {

  my ($page, $id) = @_;

  if ($id =~ m/([0-9]+)-([0-9])+-([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/) {
    $mspot_cloneq->execute($1,$2,$3);
    if ($mspot_cloneq->rows>0) {
      my ($clone_id) = $mspot_cloneq->fetchrow_array();
      return by_clone($page, $clone_id);
    }

    not_found($page, "Microarray spot identifier (SGN-S$id) was not found in SGN's databases");
  } else {
    $id =~ m/([0-9]+)/;
    $mid_cloneq->execute($1);
    if ($mid_cloneq->rows>0) {
      my ($clone_id) = $mid_cloneq->fetchrow_array();
      return by_clone($page, $clone_id);
    }

    not_found($page, "Your search was resolved to a microarray entry (SGN-S$id) that was not found in SGN's databases");
  }

}

sub try_clone_group {
    my SGN::I18N $cgi_est_try_clone_group_i18n = eval { $c && $c->i18n };
    my $est_ui_not_found_title = encode_entities(($cgi_est_try_clone_group_i18n ? $cgi_est_try_clone_group_i18n->p("global.final_caption.direct_search_result_not_found", "Direct Search Result - Not Found") : "Direct Search Result - Not Found"));

  my ($page, $id) = @_;

  $page->header();

  my $clones = "";
  while(my ($clone_id, $clone_name) = $try_clone_groupq->fetchrow_array()) {
    $clones .= "<tr><td><a href=\"/search/est.pl?request_id=$clone_id&amp;request_from=1&amp;request_type=8\">SGN-C$clone_id</a></td><td>[$clone_name]</td></tr>";
  }

  my $alias_group_message = encode_entities($cgi_est_try_clone_group_i18n ? $cgi_est_try_clone_group_i18n->p('global.est.alias_group_message', 'Your search resolved to a clone identifier (SGN-C%{id}) that has no associated reads. An alias group was detected, however. See links below for other clone ids/names that are expected to be from identical stock.', { id => $id }) : "Your search resolved to a clone identifier (SGN-C$id) that has no associated reads. An alias group was detected, however. See links below for other clone ids/names that are expected to be from identical stock.");
  my $rearray_explanation = encode_entities($cgi_est_try_clone_group_i18n ? $cgi_est_try_clone_group_i18n->p('global.est.rearray_explanation', 'This may happen for cases where clones were "rearrayed" and resequenced, but the resequenced data has not been recovered yet or the reactions failed. In this case, the rearrayed clone identifier and name will have no associated sequence, but the original clone may have usable reads available in the database.') : 'This may happen for cases where clones were "rearrayed" and resequenced, but the resequenced data has not been recovered yet or the reactions failed. In this case, the rearrayed clone identifier and name will have no associated sequence, but the original clone may have usable reads available in the database.');
  print <<EOF;
  <center>
  <h4>$est_ui_not_found_title</h4>
  </center>

  <p>$alias_group_message</p>

  <p>$rearray_explanation</p>
  <br /><br />
  <$table>$clones</table>
  <br /><br />
EOF

  $page->footer();

  exit 0;
}

sub invalid_search {
    my SGN::I18N $cgi_est_invalid_search_i18n = eval { $c && $c->i18n };
    my $est_ui_invalid_title = encode_entities(($cgi_est_invalid_search_i18n ? $cgi_est_invalid_search_i18n->p("global.final_caption.not_found_search_invalid", "Not Found - Search Invalid") : "Not Found - Search Invalid"));

  my ($page, $message) = @_;

  $page->header();

  unless (defined($message)) {$message=''};

  print <<EOF;
  <center>
  <h4>$est_ui_invalid_title</h4>
  </center>
EOF

if ($message) {
print <<EOF;
  <p>$message</p>
EOF
}

  $page->footer();

  exit (0);
}

sub not_found {
    my SGN::I18N $cgi_est_not_found_i18n = eval { $c && $c->i18n };
    my $est_ui_not_found_title = encode_entities(($cgi_est_not_found_i18n ? $cgi_est_not_found_i18n->p("global.final_caption.direct_search_result_not_found", "Direct Search Result - Not Found") : "Direct Search Result - Not Found"));

  my ($page, $message) = @_;

  $page->header();

  print <<EOF;
  <center>
  <h4>$est_ui_not_found_title</h4>
  </center>
EOF

if ($message) {
print <<EOF;
  <p>$message</p>
EOF
}

  $page->footer();

  exit(0);
}

sub not_traceable_to_est {
    my SGN::I18N $cgi_est_not_traceable_to_est_i18n = eval { $c && $c->i18n };
    my $est_ui_not_found_title = encode_entities(($cgi_est_not_traceable_to_est_i18n ? $cgi_est_not_traceable_to_est_i18n->p("global.final_caption.direct_search_result_not_found", "Direct Search Result - Not Found") : "Direct Search Result - Not Found"));

  my ($page, $id) = @_;

  $page->header();

  my $not_traceable = encode_entities(($cgi_est_not_traceable_to_est_i18n ? $cgi_est_not_traceable_to_est_i18n->p("global.final_caption.not_traceable", "The identifier %{id} of the specified type can not be traced to an EST in SGN's databases", {id => $id}) : "The identifier $id of the specified type can not be traced to an EST in SGN's databases"));
  print <<EOF;
  <center>
  <h4>$est_ui_not_found_title</h4>
  </center>

  <p>$not_traceable</p>
  <br />
EOF

  $page->footer();

  exit(0);
}

sub show_list {

  my ($page, $id) = @_;

  my $content = build_tree($page, $id);

  $page->header();

  print "<tr><td>$content</td></tr>";
  print "<br />\n";
  $page->footer();

  exit(0);
}

sub hierarchy_requested {
    my SGN::I18N $cgi_est_hierarchy_requested_i18n = eval { $c && $c->i18n };
    my $est_i18n_information_hierarchy = encode_entities($cgi_est_hierarchy_requested_i18n ? $cgi_est_hierarchy_requested_i18n->p('global.est.information_hierarchy', 'Information Hierarchy') : 'Information Hierarchy');

  my ($page, $id, $id_type) = @_;

  if ($id_type != 8) {
    # shit a brick.
  }

  my $content = build_hierarchy($page, $id);

  $page->header();
  my $hierarchy_title = encode_entities(($cgi_est_hierarchy_requested_i18n ? $cgi_est_hierarchy_requested_i18n->p('global.est.hierarchy_title', 'Information Hierarchy for Clone %{id}', { id => $id }) : "Information Hierarchy for Clone $id"));
  print page_title_html($hierarchy_title);

  if (!$content) {
    my $no_hierarchy_structure = encode_entities($cgi_est_hierarchy_requested_i18n ? $cgi_est_hierarchy_requested_i18n->p("global.est.no_hierarchy_structure", "No structure was found for identifier %{id}", { id => $id }) : "No structure was found for identifier $id");
    print <<EOF;
    $no_hierarchy_structure
EOF
    $page->footer();
  exit 0;
  }

  print blue_section_html($est_i18n_information_hierarchy,$content);
  $page->footer();

  exit 0;
}

sub build_hierarchy {

  my ($page, $clone_id) = @_;
  my $table = 'table cellpadding="0" cellspacing="1" border="0"';

  $h_cgq->execute($clone_id);
  return "" if ($h_cgq->rows == 0);

  my ($clone_group, $clone_name) = $h_cgq->fetchrow_array();


  my @clones = ();
  $clones[0] = [ $clone_id, $clone_name ];

  if ($clone_group) {
    $h_cq->execute($clone_group, $clone_id);
    while(@_ = $h_cq->fetchrow_array()) {
      push @clones, [ @_ ];
    }

  }

  my $flat = "";

  foreach my $clone ( @clones ) {
    # Lookup the reads
    $flat .= "Clone SGN-C$clone->[0] - $clone->[1]\n";

    my ($read_id, $trace_name);
    $h_traceq->execute($clone->[0]);
    $h_traceq->bind_columns(\$read_id, \$trace_name);
    while($h_traceq->fetch()) {
      $flat .= " "x4 . "Chromatogram SGN-T$read_id - $trace_name\n";

      my ($est_id, $version);
      $h_estq->execute($read_id);
      $h_estq->bind_columns(\$est_id, \$version);
      while($h_estq->fetch()) {
	$flat .= " "x8 . "Processed EST <a href=\"/search/est.pl?request_id=$est_id&amp;request_type=7&amp;request_from=1\">SGN-E$est_id</a> - version $version\n";

	my ($unigene_id, $build, $organism);
	$h_unigeneq->execute($est_id);
	$h_unigeneq->bind_columns(\$unigene_id,\$build,\$organism);
	while($h_unigeneq->fetch()) {
	  $flat .= " "x12 . "Unigene member <a href=\"/search/unigene.pl?unigene_id=$unigene_id\">SGN-U$unigene_id</a> - $organism Build $build\n";
	  $blastq->execute($unigene_id);
	  while(my ($db_name, $blast_program, $n_hits) =
		$blastq->fetchrow_array()) {
	    $flat .= " "x16 . "$n_hits stored BLAST hits against $db_name [$blast_program]\n";
	  }
# This is old from when we were displaying the entire blast hit, which we
# may want to do still...
#
#	  my ($match_id, $match_db, $evalue, $score, $identity_percentage,
#	      $alignment_length, $start, $end, $frame, $defline);
#	  $cached_blastq->bind_columns(\$match_db, \$match_id, \$evalue, \$score, \$identity_percentage, \$alignment_length, \$defline);
#	  while($cached_blastq->fetch()) {
#	    my ($whole_shebang, $link_id, $display_id) = $defline =~ m/(gi\|([0-9]+)\|(\S+))/;
#	    $defline =~ s!\Q$whole_shebang\E!$display_id!g;
#	    if (length($defline) > 70) {
#	      $defline = sprintf "%-67.67s...%6.1f%6.0g",$defline,$score,$evalue;
#	    } else {
#	      $defline = sprintf "%-70.70s%6.1f%6.0g",$defline,$score,$evalue;
#	    }
#	    $defline =~ s!\Q$display_id\E!<a href=http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=protein&list_uids=$link_id&dopt=genpept>$display_id</a>!;
#	    $flat .= " "x16 . "$defline\n";
#	  }
	}
      }
    }
  }

  return "<pre>" . $flat . "\n</pre>";
}




