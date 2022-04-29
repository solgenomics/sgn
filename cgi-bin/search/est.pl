#!/usr/bin/perl -w
use strict;
use warnings;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html page_title_html html_break_string/;
use CXGN::Chromatogram;
use URI::Escape;
use CXGN::Tools::Text qw | sanitize_string |;
use CatalystX::GlobalContext '$c';
use CXGN::DB::Connection;

my %current_unigene = ();
my %previous_unigene = ();

our ($auto_idq, $request_typeq, $cloneq, $clone_read_idq,
    $clone_groupq, $alt_readq, $arrayq, $readq, $estq, $unigeneq,
    $by_clone_idq, $by_read_idq, $mspot_cloneq, $mid_cloneq, $table,
    $h_cgq, $h_cq, $h_traceq, $h_estq, $h_unigeneq, $randomq,
    $max_estid, $blastq, $microarray_byunigeneq, $try_clone_groupq,
    $marker_mappingq, $mapped_memberq, $trace_nameq, $clone_nameq,
    @known_request_from_types);


our $page = CXGN::Page->new( "SGN EST Search Result", "Koni");

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
$page->message_page("No EST identifier specified") unless $request_id || ($random eq 'yes');


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
      not_found($page, "Identifier \"$id\" was not found in SGN's databases.");
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
  invalid_search($page, "Invalid identifier \"$id\" for specified identifier type (SGN-E#)") if ($id !~ m/^(SGN-E|E|)([0-9]+)$/);
  $match_id = "SGN-E$2";
  $est_id = $2;

} elsif ($id_type == 8) {
  invalid_search($page, "Invalid identifier \"$id\" for specified identifier type (SGN-C#)") if ($id !~ m/^(SGN-C|C|)([0-9]+)$/);
  # This is a clone internal identifier - find a trace, then find an EST
  if ($show_hierarchy) {
    hierarchy_requested($page, $id, $id_type);
  }
  $match_id = "SGN-C$2";
  $est_id = by_clone($page, $2);
} elsif ($id_type == 9) {
  # This is a trace identifier, find the most recent sequence for it
  invalid_search($page, "Invalid identifier \"$id\" for specified identifier type (SGN-T#)") if ($id !~ m/^(SGN-T|T|)([0-9]+)$/);
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
<tr><td width="50%"><b>Request:</b> $request_id</td><td><b>Match:</b> $match_id</td></tr>
<tr><td><b>Request From:</b> $request_from</td><td><b>Match Type:</b> $id_type_name</td></tr>
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
  $organism_name = "Unknown" if !defined($organism_name);
  $tissue = "Unknown" if !defined($tissue);

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
	  $microarray .= qq{Alias clone <a href="/search/est.pl?request_id=$_->[0]&request_type=8&request_from=1">SGN-C$_->[0]</a> is on microarray $chip_name: SGN-S$version-$release-$spot_id\n};
	} else {
	  $microarray .= qq{SGN-C$_->[0] is on microarray $chip_name spot ID $version-$release-$spot_id [<a href="http://bti.cornell.edu/CGEP/CGEP.html">Order</a>] [<a href="http://ted.bti.cornell.edu/cgi-bin/array/basicsearch.cgi?arrayID=$version-$release-$spot_id">Tomato Microarray Database</a>]\n};
	}
      }
    }
    $microarray ||= '<span class="ghosted">This clone is not found on any microarray</span>';
    $microarray = "<b>Microarray:</b> $microarray<br />";
  }

  my $ordering;
  if ($order_routing_id) {
    $ordering = qq{<table cellpadding="1" cellspacing="0" border="0"><tr><td><a href="/search/clone-order.pl?add_clone=$clone_name"><img src="/documents/img/sgn-cart.gif" border="0" alt="cart" /></a></td><td>Order Clone</td></tr></table>};
  } else {
    $ordering = qq{<table cellpadding="1" cellspacing="0" border="0"><tr><td><img src="/documents/img/sgn-nocart.gif" border="0" alt="nocart" /></td><td><span class="ghosted">Ordering Not Available</span></td></tr></table>};
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
    <tr><td width="40%"><b>SGN ID:</b> SGN-C$clone_id</td><td><b>Clone name:</b> $clone_name</td><td width="20%" rowspan="2">$ordering</td></tr>
    <tr><td><b>Library Name:</b> $library_name</td><td><b>Organism:</b> $organism_name</td></tr>
    </table>
    <br />
    <b>Tissue:</b> $tissue<br />
    <b>Development Stage:</b> $development_stage<br />
    <br />
    $microarray
EOF

} else {
  # no clone information was found
  $clone_info = '<div><span class="ghosted">No clone information found</span></div>';
  $clone_name = "clone name unknown";
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
    $seqdir = "Unknown";
  } elsif ($seqdir eq "5") {
    $seqdir = "5'";
  } elsif ($seqdir eq "3") {
    $seqdir = "3'";
  } else {
    $seqdir = "Unknown";
  }

  $submitter_name = '<span class="ghosted">None</span>' unless $submitter_name;
  $atb_display ||= $atb_organization;
  if ($atb_display) {
    $atb_display = "<b>Funding Organization:</b>&nbsp;$atb_display";
  }

  my $view_link='[<span class="ghosted">View</span>]';
#  my $view_link=" [<a href=\"/tools/trace_view.pl?read_id=$read_id&est_id=$est_id\">View</a>]";
  my $tmp_tracename;
  if($tmp_tracename=CXGN::Chromatogram::has_abi_chromatogram($read_id))
  {
      my $path_to_remove = $c->path_to( $c->tempfiles_subdir('traceimages') );
      $tmp_tracename=~s/$path_to_remove//;
      my $file=URI::Escape::uri_escape("$tmp_tracename");
      $view_link=" [<a href=\"/tools/trace_view.pl?file=$file&temp=yes\">View</a>]";
  }

  $read_info = <<EOF;
    <$table>
      <tr><td width="50%"><b>SGN-ID:</b> SGN-T$read_id [<a href="/search/trace_download.pl?read_id=$read_id">Download</a>]$view_link</td>
          <td><b>Facility Assigned ID:</b> $chroma_name\n</td>
      </tr>
      <tr><td><b>Submitter:</b> $submitter_name</td>
          <td><b>Sequencing Facility:</b> $facility_name</td>
      </tr>
    </table>

  $atb_display
EOF
} else {
  $read_info='<span class="ghosted">No chromatogram information found for this sequence</span>';
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
      $see_also = "[See links to 3' reads above]";
    } elsif ($seqdir eq "3'" && $dir eq "5'") {
      $see_also = "[See links to 5' reads above]";
    }

    $facility = "Unknown" if !defined($facility);
    $alt_reads .= <<EOF
      <tr><td><b>Clone:</b> SGN-C$_->[0] [$clone_name]</td>
	  <td><b>Trace:</b> SGN-T$trace_id</td>
	  <td><b>EST:</b> <a href="/search/est.pl?request_id=$eid&amp;request_type=7&amp;request_from=1">SGN-E$eid</a></td>
	  <td><b>Direction:</b> $dir</td>
	  <td><b>Facility:</b> $facility</td>
      </tr>
EOF
  }
}
if($alt_reads) {
  $alt_reads = "<table>$alt_reads</table>" ;
} else {
  $alt_reads = '<span class="ghosted">No additional reads found.</span>';
}


$estq->execute($est_id);
if ($estq->rows == 0) {
  not_found($page,"No database entry was found for EST identifier SGN-E$est_id");
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
  $display_status = "Current Version";
}
if ($status & 0x1) {
  $display_status .= "Legacy ";
}
if ($status & 0x2) {
  $display_status .= "Discarded ";
}
if ($status & 0x4) {
  $display_status .= "Deprecated ";
}
if ($status & 0x8) {
  $display_status .= "Censored ";
}
if ($status & 0x10) {
  $display_status .= "Vector/Quality trimming not applied ";
}
if ($status & 0x20) {
  $display_status .= "Contaminants not assessed ";
}
if ($status & 0x40) {
  $display_status .= "Chimera not assessed ";
}

my $insert_recovery = "";
my $vector_signature = "";
if (!($status & 0x11)) {
  $expected_error = sprintf "%7.4f",$expected_error;
  $entropy = sprintf "%5.3f",$entropy;


  my @vector_sig_strings =
    ("5' sequence read -- flanking 3' vector arm detected.",
     "3' sequence read -- flanking 5' vector arm detected.",
     "5' sequence read, incomplete (flanking vector not found)",
     "3' sequence read, incomplete (flanking vector not found)",
     #make these red and bold
     (map {'<span style="color: red; font-weight: bold;">'.$_.'</span>'}
      ('No vector sequence detected',
       'Vector found but pattern inconsistent with a normal insert',
       'Multiple cloning site sequence detected -- chimeric clone suspected.',
      )
     ),
    );

  $vector_signature = $vector_sig_strings[$vs_status]
    || '<span class="ghosted">Not available</span>';


  ### render any flags as html
  my @flag_strings = ('Vector anomaly',
		      'Possibly chimeric (anomalous insert into vector)',
		      'Too short after trimming low-quality bases',
		      'High expected error (low overall quality)',
		      'Low complexity',
		      'E. Coli (cloning host) sequence detected',
		      'rRNA contamination detected',
		      "Possibly chimeric (ends match significantly different genes in arabidopsis)",
		      "Possibly chimeric, detected by unigene assembly preclustering",
		      "Manually censored by SGN staff");
		
  my $flags_display = "";
  if ($flags == 0) {
    $flags_display = "Passed all screens and filters";
  } else {
    my @flags = ();

    my $ind = 0;
    foreach my $str (@flag_strings) {
      push @flags,$str if $flags & (1<<$ind++);
    }

    $flags_display = qq{<$table><tr><td width="10%"><b>Problems: </b></td><td>} . join("<br />",@flags) . "</td></tr></table>";
  }

  $insert_recovery= <<EOF;
<$table><tr><td width="50%"><b>Processed By:</b> SGN</td>
            <td><b>Basecalling Software:</b> phred</td>
       </tr>
</table>
<b>Vector Signature:</b> $vector_signature<br />
$flags_display
<table cellspacing="0" cellpadding="0" border="0" width="90%" align="center">
  <tr><td><b>Sequence Entropy:</b> $entropy</td>
      <td><b>Expected Error Rate:</b> $expected_error</td>
      <td><b>Quality Trim Threshold:</b> $qtrim_threshold</td>
  </tr>
</table>
EOF
} else {
  $insert_recovery = "<span class=\"ghosted\">Processing information not available for this sequence</span>";
}

my $sequence_info = <<END_HTML;
  <$table>
  <tr><td width="50%"><b>Sequence Id:</b> SGN-E$est_id</td><td><b>Length:</b> $seq_length</td></tr>
  <tr><td><b>Status:</b> $display_status</td><td><b>Direction:</b> $seqdir $see_also</td></tr>
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
	$alt_microarray .= qq{See unigene <a href="/search/unigene.pl?unigene_id=$unigene_id">SGN-U$unigene_id</a> for alternatives which are available on a microarray<br />};
      }
    }
  }

  $marker_mappingq->execute($clone_id);
  if ($marker_mappingq->rows > 0) {
    while (my ($marker_id, $alias) = $marker_mappingq->fetchrow_array()){
      $alt_mapped .= qq{This clone has been mapped as <a href="/search/markers/markerinfo.pl?marker_id=$marker_id">$alias</a>.<br />} 
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
	$alt_mapped .= qq{See unigene <a href="/search/unigene.pl?unigene_id=$unigene_id">SGN-U$unigene_id</a> for alternative clones/ESTs which are mapped};
      }
    }
  }
  push @recent, <<EOF;
  <tr><td>[SGN-E$eid]  </td>
      <td><a href="/search/unigene.pl?unigene_id=$unigene_id&amp;highlight=$eid">SGN-U$unigene_id</a></td>
      <td>$og_name        </td>
      <td>Build $build_nr </td>
      <td>$nr_members ESTs assembled</td>
  </tr>
EOF
}

if (!$alt_microarray &&
    ($organism_id == 1 || $organism_id == 2 || $organism_id == 3)) {
  $alt_microarray = '<span class="ghosted">No alternative clones from any current unigene containing this EST are available on a microarray</span>';
}

$alt_mapped ||= "<div><span class=\"ghosted\">There is no map position defined on SGN for this EST or others in the same unigene.</span></div>";



$unigene_content = '<table align="center" cellspacing="0" cellpadding="0" border="0" width="100%">';

if ($other_estid) {
  $unigene_content .= qq{<tr><td colspan="6"><span class="ghosted">Note: Some unigenes listed here are assembled from different versions of the sequence displayed above. Note SGN-E# in left column. All versions were derived from the same chromatogram</span></td></tr><tr><td colspan="6"><br /></td></tr>};
}

if (@recent) {
  $unigene_content .= <<EOF;
<tr><td colspan="6"><b>Current Unigene builds</b></td></tr>
@recent
<tr><td colspan="6" align="center"><span class="ghosted">Follow SGN-U# link for detailed information and annotations</span></td></tr>
EOF
} else {
  $unigene_content .= <<EOF;
<tr><td align="left" colspan="6"><b>Current Unigene builds</b></td></tr>
<tr><td colspan="6"><span class="ghosted">No current unigene builds incorporate this sequence</td></tr>
EOF
}

$unigene_content .= "</table>";


$page->header();
print page_title_html("EST details &mdash; $match_id");
print blue_section_html('Search information',$search_info);
print blue_section_html('Clone information',<<EOH);
$clone_info
$alt_microarray
$alt_mapped
EOH
$alt_reads .= qq{<center style="margin-top: 0.8em"><a href="/search/est.pl?request_id=$clone_id&amp;request_type=8&amp;request_from=1&amp;show_hierarchy=1">[Show information hierarchy]</a></center>};
print blue_section_html('Additional sequencing',$alt_reads);
print blue_section_html('Sequence',$sequence_info);
print blue_section_html('Unigenes',$unigene_content);
print blue_section_html('Chromatogram',$read_info);
print blue_section_html('Quality processing',$insert_recovery);

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
  my ($page, $id) = @_;

  $page->header();

  my $clones = "";
  while(my ($clone_id, $clone_name) = $try_clone_groupq->fetchrow_array()) {
    $clones .= "<tr><td><a href=\"/search/est.pl?request_id=$clone_id&amp;request_from=1&amp;request_type=8\">SGN-C$clone_id</a></td><td>[$clone_name]</td></tr>";
  }

  print <<EOF;
  <center>
  <h4>Direct Search Result - Not Found</h4>
  </center>

  <p>Your search resolved to a clone identifier (SGN-C$id) that has no associated reads. An alias group was detected, however. See links below for other clone ids/names that are expected to be from identical stock. </p>

  <p>This may happen for cases where clones were "rearrayed" and resequenced, but the resequenced data has not been recovered yet or the reactions failed. In this case, the rearrayed clone identifier and name will have no associated sequence, but the original clone may have usable reads available in the database.</p>
  <br /><br />
  <$table>$clones</table>
  <br /><br />
EOF

  $page->footer();

  exit 0;
}

sub invalid_search {
  my ($page, $message) = @_;

  $page->header();

  unless (defined($message)) {$message=''};

  print <<EOF;
  <center>
  <h4>Not Found - Search Invalid</h4>
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
  my ($page, $message) = @_;

  $page->header();

  print <<EOF;
  <center>
  <h4>Direct Search Result - Not Found</h4>
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
  my ($page, $id) = @_;

  $page->header();

  print <<EOF;
  <center>
  <h4>Direct Search Result - Not Found</h4>
  </center>

  <p>The identifier $id of the specified type can not be traced to an EST in SGN\'s databases</p>
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
  my ($page, $id, $id_type) = @_;

  if ($id_type != 8) {
    # shit a brick.
  }

  my $content = build_hierarchy($page, $id);

  $page->header();
  print page_title_html("Information Hierarchy for Clone $id");

  if (!$content) {
    print <<EOF;
    No structure was found for identifier $id
EOF
    $page->footer();
  exit 0;
  }

  print blue_section_html('Information Hierarchy',$content);
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




