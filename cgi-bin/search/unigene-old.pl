#!/usr/bin/perl -w
use strict;

use File::Spec;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/
				     page_title_html
				     blue_section_html
				     columnar_table_html
				     info_table_html
				     html_break_string
				    /;
use CXGN::Tools::Text qw/abbr_latin/;
use CXGN::Tools::Identifiers qw/link_identifier/;
use CXGN::Tools::File qw/file_contents/;

use CXGN::VHost;
use CXGN::Unigene::Tools;
use CXGN::Apache::Error;
use CXGN::DB::Connection;
use CXGN::Marker;
use CXGN::Alignment;
use File::Temp;

my $vhost_conf=CXGN::VHost->new();

our ($legacyq, $unigeneq, $consensiq, $singletq, $memberq, $blastq, $blast_hitq, $unigene_precedingbuildq, $unigene_precededq, $signalpq,
     $manual_annotq, $library_repq, $unigene_buildstatusq, $unigene_updatedq, $unigene_supersedingbuildq, %lib_sizes, $table, $section_header, 
     $image_program, $microarrayq, $mapped_memberq, @random_unigene_ids,$estscan_pepq, $iprq, $dmq, $goq, $family_group_q, $family_q, $family_member_q);

our $page = CXGN::Page->new("SGN Unigene Search", "Koni");

# A few constants for this script
$table = "table cellspacing=\"0\" cellpadding=\"0\" border=\"0\" width=\"100%\"";
$section_header = "bgcolor=\"#CCCCFF\"";
$image_program = File::Spec->catfile($vhost_conf->get_conf('basepath'),
				     $vhost_conf->get_conf('programs_subdir'),
				     'draw_contigalign',
				    );
my $basepath = $vhost_conf->get_conf('basepath');
my $tmpdir = File::Spec->catdir($vhost_conf->get_conf('tempfiles_subdir'),
				'unigene_images'
			       );

# Make a persistent connection to the database, and prepare the queries
# we will need in advance. Subsequent requests to this script will only
# need to execute the statements, not setup a connection and (re)prepare
# these queries.
my $dbh = CXGN::DB::Connection->new();

$legacyq = $dbh->prepare("	SELECT unigene_id FROM unigene 
							WHERE unigene_build_id=? 
							AND cluster_no=? AND contig_no=?	");

$unigeneq = $dbh->prepare("	SELECT nr_members, cluster_no, groups.comment, build_nr, build_date, database_name, sequence_name 
							FROM unigene 
							LEFT JOIN unigene_build USING (unigene_build_id) 
							LEFT JOIN groups ON (groups.group_id=unigene_build.organism_group_id) 
							WHERE unigene_id=?	");

$consensiq = $dbh->prepare("SELECT seq 
							FROM unigene 
							LEFT JOIN unigene_consensi USING (consensi_id) 
							WHERE unigene_id=?");

# Note that trimming is applied here if a qc_report entry is found with
# non-null hqi entries. Otherwise, the sequence as stored is returned.
$singletq = $dbh->prepare("	SELECT COALESCE(substring(seq FROM (hqi_start)::int+1 FOR (hqi_length)::int ),seq) 
							FROM unigene 
							LEFT JOIN unigene_member USING (unigene_id) 
							LEFT JOIN est USING (est_id) 
							LEFT JOIN qc_report USING (est_id) 
							WHERE unigene.unigene_id=?	");

# This is a little LEFT-JOIN happy, but we want to use the clone name
# as a "content-specific-tag" if we can
$memberq = $dbh->prepare("	SELECT unigene_member.est_id, clone_name, dir, start, stop, qstart, qend 
							FROM unigene 
							LEFT JOIN unigene_member USING (unigene_id) 
							LEFT JOIN est USING (est_id) 
							LEFT JOIN seqread USING (read_id) 
							LEFT JOIN clone USING (clone_id) 
							WHERE unigene.unigene_id=?	");

$blastq = $dbh->prepare("	SELECT blast_annotation_id, blast_targets.blast_target_id, blast_program, db_name, hits_stored 
							FROM blast_annotations 
							LEFT JOIN blast_targets USING (blast_target_id) 
							WHERE apply_id=? and apply_type=15	");

$blast_hitq = $dbh->prepare("	SELECT blast_hits.target_db_id, evalue, score, identity_percentage, apply_start, apply_end, defline from blast_hits 
								LEFT JOIN blast_defline USING (defline_id) 
								WHERE blast_annotation_id=? 
								ORDER BY score DESC");

$microarrayq = $dbh->prepare("	SELECT clone.clone_id, est.est_id, seqread.direction, chip_name, release, microarray.version, spot_id, content_specific_tag 
								FROM unigene 
								LEFT JOIN unigene_member USING (unigene_id) 
								LEFT JOIN est USING (est_id) 
								LEFT JOIN seqread using (read_id) 
								LEFT JOIN clone using (clone_id) 
								INNER JOIN microarray using (clone_id) 
								WHERE unigene.unigene_id=? 
								ORDER BY clone.clone_id	");

$mapped_memberq = $dbh->prepare
("
    SELECT 
        ests_mapped_by_clone.clone_id, 
        marker_id
    FROM 
        unigene_member 
        INNER JOIN est USING (est_id) 
        INNER JOIN seqread USING (read_id) 
        INNER JOIN ests_mapped_by_clone USING (clone_id) 
    WHERE 
        unigene_id=?
");

$estscan_pepq = $dbh->prepare("SELECT protein_seq FROM cds WHERE unigene_id=?");

$iprq = $dbh->prepare("	SELECT i.interpro_accession, i.description 
						FROM domain_match AS dm, domain AS d, interpro AS i 
						WHERE dm.domain_id = d.domain_id 
							AND d.interpro_id = i.interpro_id 
							AND dm.hit_status = 'T' 
							AND dm.unigene_id=?	");

$goq = $dbh->prepare("	SELECT g.go_accession, g.description 
						FROM domain_match AS dm,  
							domain AS d, 
							interpro AS i, 
							interpro_go AS ig, 
							go AS g 
						WHERE dm.domain_id = d.domain_id 
							AND d.interpro_id = i.interpro_id 
							AND i.interpro_accession = ig.interpro_accession 
							AND ig.go_accession = g.go_accession 
							AND dm.hit_status = 'T' 
							AND dm.unigene_id=?	");

$dmq = $dbh->prepare("	SELECT interpro_accession, match_begin, match_end 
						FROM interpro 
						LEFT JOIN domain USING (interpro_id) 
						LEFT JOIN domain_match USING (domain_id) 
						WHERE unigene_id = ? 
							AND hit_status LIKE 'T'		");

######################################################
#This part is for gene family

$family_q = $dbh->prepare("	SELECT i_value, family.family_id, family_annotation, status
							FROM sgn.family_build 
							INNER JOIN sgn.family USING (family_build_id) 
							INNER JOIN sgn.family_member USING (family_id) 
							INNER JOIN cds USING (cds_id) 
							WHERE unigene_id = ?
						");

$family_member_q = $dbh->prepare("	SELECT count(family_member_id) 
									FROM family_member 
									WHERE family_id = ? 
									GROUP BY family_id	");
######################################################
#manual annotation info based on clone membership;
#target type name is used in where clause rather than id for type subselection
#Dan, 2003-09-17
$manual_annotq = $dbh->prepare("
		SELECT sgn_people.sp_person.first_name || ' ' || sgn_people.sp_person.last_name, 
				manual_annotations.date_entered, 
				manual_annotations.last_modified, 
				manual_annotations.annotation_text, 
				clone.clone_name, 
				clone.clone_id 
		FROM unigene 
		LEFT JOIN unigene_member USING (unigene_id) 
		LEFT JOIN est USING (est_id) LEFT JOIN seqread USING (read_id) 
		LEFT JOIN clone USING (clone_id) 
		LEFT JOIN manual_annotations ON (clone.clone_id = manual_annotations.annotation_target_id) 
		LEFT JOIN sgn_people.sp_person ON (manual_annotations.author_id = sgn_people.sp_person.sp_person_id) 
		LEFT JOIN annotation_target_type ON (manual_annotations.annotation_target_type_id = annotation_target_type.annotation_target_type_id) 
		WHERE unigene.unigene_id=? 
			AND annotation_target_type.type_name='clone'
		");
#library representation in this unigene (mini version of digital expression)
# Dan, 2003-10-29
$library_repq = $dbh->prepare("	SELECT count(*), l.library_id, min(l.library_shortname), min(l.tissue), min(l.development_stage), min(o.organism_name) 
								FROM unigene 
								LEFT JOIN unigene_member USING (unigene_id) 
								LEFT JOIN est USING (est_id) 
								LEFT JOIN seqread USING (read_id) 
								LEFT JOIN clone USING (clone_id) 
								LEFT JOIN library AS l USING (library_id) 
								LEFT JOIN organism AS o USING (organism_id) 
								WHERE unigene.unigene_id=? 
								GROUP BY l.library_id	");

#Check build of the unigene to see if it is in a current build or deprecated
$unigene_buildstatusq = $dbh->prepare("	SELECT status 
										FROM unigene_build 
										JOIN unigene USING (unigene_build_id) 
										WHERE unigene_id=?	");

#Find superseding build name, given unigene_id
$unigene_supersedingbuildq = $dbh->prepare
("
	SELECT groups.comment, build_nr FROM unigene_build 
		JOIN groups ON (organism_group_id=group_id)
	WHERE
		unigene_build_id = 
		( SELECT latest_build_id FROM unigene_build
		  WHERE
			unigene_build_id =
			( SELECT unigene_build_id FROM unigene
			  WHERE
				unigene_id=?
			)
		)
");

#Find preceding build name, given unigene_id
$unigene_precedingbuildq = $dbh->prepare
("
	SELECT groups.comment, build_nr FROM unigene_build 
		JOIN groups ON (organism_group_id=group_id)
	WHERE
		unigene_build_id = 
		( SELECT unigene_build_id FROM unigene_build
		  WHERE
			next_build_id =
			( SELECT unigene_build_id FROM unigene
			  WHERE
				unigene_id=?
			)
		)
");



#If the build is deprecated, run this query to find the updated unigene(s)
$unigene_updatedq = $dbh->prepare
("
	SELECT distinct unigene_id FROM unigene_member
		JOIN unigene USING (unigene_id) 
		JOIN unigene_build USING (unigene_build_id) 
	WHERE 
		est_id IN 
			(select est_id FROM unigene_member WHERE unigene_id=?)  
		AND status = 'C' 
		AND unigene_build_id = 
			( SELECT latest_build_id FROM unigene_build 
			  WHERE unigene_build_id = 
			  	( SELECT unigene_build_id FROM unigene 
				  WHERE unigene_id=?
				)
			)
");

#Find the preceding unigene(s) if there is a preceding build
$unigene_precededq = $dbh->prepare
("
	SELECT distinct unigene_id FROM unigene_member
		JOIN unigene USING (unigene_id) 
		JOIN unigene_build USING (unigene_build_id) 
	WHERE 
		est_id IN 
			(select est_id FROM unigene_member WHERE unigene_id=?)  
		AND unigene_build_id = 
			( SELECT unigene_build_id FROM unigene_build 
			  WHERE next_build_id = 
			  	( SELECT unigene_build_id FROM unigene 
				  WHERE unigene_id=?
				)
			)
");

$signalpq = $dbh->prepare 
(" 	SELECT nn_ypos, nn_score, nn_d 
	FROM unigene_signalp 
	WHERE unigene_id=? 
");

	

#get the library sizes
my $lib_sizeq = $dbh->prepare("SELECT library_id, count(*) FROM clone GROUP BY library_id");
$lib_sizeq->execute();
while (my ($lib_id, $lib_count) = $lib_sizeq->fetchrow_array()){
  $lib_sizes{$lib_id}=$lib_count;
}

my ($unigene_id, $force_image, $random, $highlight) =
  $page->get_arguments("unigene_id","force_image","random","highlight");

if ($unigene_id eq "legacy") {
  my ($build_id, $cluster, $contig) =
    $page->get_arguments("unigene_build","cluster", "contig");
  $legacyq->execute($build_id, $cluster, $contig);
  if ($legacyq->rows == 0) {
    legacy_not_found($page, $build_id, $cluster, $contig);
  }
  ($unigene_id) = $legacyq->fetchrow_array();
}

if ($random eq "yes") {
  if (@random_unigene_ids==0) {
    prep_random_search();
  }
  $unigene_id = shift @random_unigene_ids;
}

if ($unigene_id eq "") {
  empty_search($page);
}

# Added to allow people to use the SGN-U prefix, if that is how they feel
# about it...
if ($unigene_id =~ m/^(|U|SGN-U)([0-9]+)$/) {
  $unigene_id=$2;
}

if (int($unigene_id) eq $unigene_id) {
  result($page,$unigene_id,$force_image,$highlight);
}

invalid_search($page, $unigene_id);

# This function is called when the unigene # is known. It will produce the
# output page.
sub result {
  my ($page, $unigene_id, $force_image, $highlight) = @_;
  # This gets us the meta information about the unigene in question
  $unigeneq->execute($unigene_id);
  if ($unigeneq->rows == 0) {
    not_found($page, $unigene_id);
  }
  my ($nr_members, $cluster_no, $org_group_name, $build_nr, $build_date, $database_name, $sequence_name) =
    $unigeneq->fetchrow_array();

  # Here we get the FASTA sequence. Note the application of trimming
  # if needed for EST sequences (unigene singlet)
  my ($seq, $unigene_length);
  if ( $nr_members > 1) {
    $consensiq->execute($unigene_id);
    ($seq) = $consensiq->fetchrow_array();
  } else {
    $singletq->execute($unigene_id);
    ($seq) = $singletq->fetchrow_array();
  }
  $unigene_length = length($seq);
  my $i = 0;
  my $seq_display = html_break_string($seq,90);

  my $unigene_content = <<EOF;
    <table width="100%">
    <tr>
    <td><b>ID:</b> SGN-U$unigene_id<br /><b>Build:</b> $build_nr<br /><b>Date:</b> $build_date<br /><b>Organism:</b> $org_group_name<br /><b>Other Identifier:</b> $database_name-U$sequence_name<br /><br />
    </td>
    <td class="right">
[<a href="/tools/blast/?preload_id=$unigene_id&amp;preload_type=15">BLAST</a>]&nbsp;[<a href="/tools/sixframe_translate.pl?unigene_id=$unigene_id">AA Translate</a>]
    </td></tr>
   <tr><td colspan="2">&gt;SGN-U$unigene_id  $org_group_name Build $build_nr ($nr_members members)</td></tr>
   <tr><td colspan="2"><span class="sequence">$seq_display</span></td></tr>
   </table>

EOF

	#Check to see if unigene is up to date, and find the updated unigene if it is not.  We will want to display this before the "unigene_content" 
	#but this content relies on the $org_group_name and $build_nr from the meta-query
	my $unigene_buildstatus;
	my @updated_unigene = ();
	my $deprecate_content = "";
	$unigene_buildstatusq->execute($unigene_id);
	($unigene_buildstatus) = $unigene_buildstatusq->fetchrow_array();
	if($unigene_buildstatus ne 'C'){
		$deprecate_content = "<div class=\"deprecated\">";
		$deprecate_content .= "This unigene is from an out-of-date build, <em>$org_group_name #$build_nr</em>";
		$unigene_updatedq->execute($unigene_id, $unigene_id);
		while(my ($new_unigene) = $unigene_updatedq->fetchrow_array()){
			push(@updated_unigene, $new_unigene);
		}
		$unigene_supersedingbuildq->execute($unigene_id);
		my ($new_build_organism, $new_build_nr) = $unigene_supersedingbuildq->fetchrow_array();
		$deprecate_content .= "<span style=\"color:black\">";
		if(@updated_unigene == 0){ $deprecate_content .= "<br>It does not exist"; }
		elsif(@updated_unigene == 1){
			$deprecate_content .= "<br />It has been superseded by <a href='unigene.pl?unigene_id=" . $updated_unigene[0] . "'>SGN-U" . 
									$updated_unigene[0] . "</a>";
		}
		elsif(@updated_unigene > 1){
			$deprecate_content .= "<br />It has been split into ";
			my $i = 0;
			while($i < @updated_unigene){
				if ($i > 0 && @updated_unigene!=2) { $deprecate_content .= ", "}
				elsif($i > 0) { $deprecate_content .= " " }
				if ($i == @updated_unigene - 1) { $deprecate_content .= "and " }
				$deprecate_content .= "<a href='unigene.pl?unigene_id=" . $updated_unigene[$i] . "'>SGN-U" . $updated_unigene[$i] . "</a>"; 
				$i++;
			}
		}
		$deprecate_content .= " in the current build, <em style='white-space:nowrap'>$new_build_organism #$new_build_nr</em>";
		$deprecate_content .= "</span></div>";
	}

	## Find out if there is a preceding build.  If there is such a build, find the preceding unigenes and fill the preceding_content
	my $preceding_content = "";
	$unigene_precedingbuildq->execute($unigene_id);
	my ($preceding_build_name, $preceding_build_nr) = $unigene_precedingbuildq->fetchrow_array();
	if(defined $preceding_build_name){
		my @preceding_unigene = ();	
		$unigene_precededq->execute($unigene_id, $unigene_id);
		while(my @array = $unigene_precededq->fetchrow_array){
			push(@preceding_unigene, $array[0]);
		}
		my @preceding_unigene_content = ();
		foreach(@preceding_unigene){
			push(@preceding_unigene_content, ["<a href='unigene.pl?unigene_id=SGN-U$_'>SGN-U$_</a>", "$preceding_build_name #$preceding_build_nr"]);
		}
		
		unless(@preceding_unigene) {
			$preceding_content = "<span class='ghosted'>None in previous build: $preceding_build_name #$preceding_build_nr</span>";
		}
		else {
			$preceding_content = columnar_table_html(headings => ['Unigene', 'Build'], data=> \@preceding_unigene_content);
		}

	}
	
  my @members = ();
  my $highlight_id = "none";
  my $highlight_link="";
  $memberq->execute($unigene_id);
  while(@_ = $memberq->fetchrow_array()) {
    # This is supposed to be handled more elegantly when highlighting options are
    # upgraded beyond just "draw a box around this EST" -- say when all ESTs from
    # a particular library are highlighted, or something. The dirty work could be handled
    # by SQL, just have a column that is 1 for highlight, 0 for don't highlight.
    if ($highlight && ($_[0]==$highlight)) {
      push @members, [ @_, 1 ];
      # This is used in the "Show Image" link if the image will be supressed by default
      # Checking it here serves to validate it rather than pass on whatever, not that it
      # matters since all this will be repeated anyway if the user clicks the link
      $highlight_link="&amp;highlight=$_[0]";
      # THis makes the filename unique so the image is regenerated -- if highlighting
      # options get more complicated, this crap should be defenestrated and the image
      # regenerated every time rather than this silly caching scheme.
      $highlight_id="$_[0]";
    } else {
      push @members, [ @_, 0 ];
    }
  }

  my $alignment_content;
  if ( ($nr_members > 1 && $nr_members < 20) || $force_image )  {
    my $img_relpath  = File::Spec->catfile($tmpdir,   "unigene-$unigene_id-alignment-img-${highlight_id}.png");
    my $map_relpath  = File::Spec->catfile($tmpdir,   "unigene-$unigene_id-map.html");
    my $img_fullpath = File::Spec->catfile($basepath, $tmpdir, "unigene-$unigene_id-alignment-img-${highlight_id}.png");
    my $map_fullpath = File::Spec->catfile($basepath, $tmpdir, "unigene-$unigene_id-map.html");

    # Generate the unigene image unless it already exists. A butt-wiper
    # (ie, tmpwatch) should clean the files automatically which should
    # allow them to "expire" and keep the overall size of the cached files
    # from growing outrageously. Perhaps a startup perl script for the
    # webserver should wipe the directory as well so a server restart can
    # be used to clear cached files.
    if (! -f $img_fullpath || ! -f $map_fullpath ) {
      my $stuff="| $image_program --imagefile=\"$img_fullpath\" --mapfile=\"$map_fullpath\" --link_basename=\"/search/est.pl?request_from=1&request_type=7&request_id=\" --image_name=\"SGN-U$unigene_id\"";
      open IMAGE_PROGRAM,$stuff;
      foreach ( @members ) {
	my ($strim, $etrim) = ($_->[5] - $_->[3], $_->[4] - $_->[6]);
	my $label = sprintf "%-12s %-10s","SGN-E$_->[0]",$_->[1];
	print IMAGE_PROGRAM join( "\t", $label,
				  @{$_}[0,2,3,4], $strim, $etrim, $_->[7]),"\n";
      }
      close IMAGE_PROGRAM
	or CXGN::Apache::Error::notify('failed to display unigene alignment image',"Non-zero exit code from unigene alignment imaging program $image_program ($?)");
    }


    my $hide_image= "";
    if ($nr_members == 1 || $nr_members > 20) {
      $hide_image = qq{<br />[<a href="/search/unigene.pl?unigene_id=$unigene_id&amp;force_image=0$highlight_link">Hide Image</a>]};
    }

    my $map;
    eval {
      $map = file_contents($map_fullpath)
    };
    if ($@){
      CXGN::Apache::Error::notify("could not open image map file","Could not open existing(?) image map file ($@)");
    }

    $alignment_content = <<EOF;
      <center>
      <img src="$img_relpath" border="0" usemap="#contigmap_SGN-U$unigene_id" />
      $map
      <br /><span class="ghosted">To view details for a particular member sequence, click the SGN-E# identifier.</span>$hide_image
      </center>
EOF

  } else {
    if ($nr_members == 1) {
      # Don't bother passing the highlight option around here -- there is only one EST
      $alignment_content = <<EOF;
      <center>
      <span class="ghosted">Alignment image suppressed for unigene with only one aligned EST <a href="/search/est.pl?request_id=$members[0]->[0]&request_type=7&request_from=X">SGN-E$members[0]->[0]-$members[0]->[1]</a></span><br />
      [<a href="/search/unigene.pl?unigene_id=$unigene_id&amp;force_image=1">Show Image</a>]
      </center>
EOF
    } else {
      # If a highlight option was passed in, pass it on...
      $alignment_content = <<EOF;
      <center>
      <span class="ghosted">Alignment image suppressed for unigene with $nr_members aligned sequences.</span><br />
      [<a href="/search/unigene.pl?unigene_id=$unigene_id&amp;force_image=1$highlight_link">Show Image</a>]
      </center>
EOF
    }
  }

  # Don't know how to check for mapped sequences right now
  my @mapped = ();

  # Check for microarray occurances
  my @microarray = ();
  $microarrayq->execute($unigene_id);
  while(my ($clone_id, $est_id, $read_dir, $chip_name, $release, $version, $spot_id, 
	    $content_specific_tag) = $microarrayq->fetchrow_array()) {

    if (!defined($read_dir)) {
      $read_dir = "<span class=\"ghosted\">Unknown</span>";
    } elsif ($read_dir eq "+") {
      $read_dir = "5'";
    } else {
      $read_dir = "3'";
    }

#     push @microarray, <<EOF
#       <tr><td>SGN-C$clone_id</td>
#           <td>[<a href="/search/est.pl?request_id=$est_id&request_from=1&request_type=7">SGN-E$est_id</a>] $read_dir</td>
#           <td><b>Chip Name:</b> $chip_name</td>
#           <td><b>Spot ID:</b> $release-$version-$spot_id-$content_specific_tag</td>
#           <td>[<a href="http://bti.cornell.edu/CGEP/CGEP.html">Order&nbsp;Array</a>]&nbsp;[<a href="http://ted.bti.cornell.edu/cgi-bin/array/basicsearch.cgi?arrayID=$release-$version-$spot_id">TMD</a>]</td></tr>
# EOF
    push @microarray, ["SGN-C$clone_id",
		       qq|[<a href="/search/est.pl?request_id=$est_id&request_from=1&request_type=7">SGN-E$est_id</a>]|,
		       $read_dir,
		       $chip_name,
		       "$release-$version-$spot_id-$content_specific_tag",
		       qq|[<a href="http://bti.cornell.edu/CGEP/CGEP.html">Order&nbsp;Array</a>]|,
		       qq|[<a href="http://ted.bti.cornell.edu/cgi-bin/array/basicsearch.cgi?arrayID=$release-$version-$spot_id">TMD</a>]|,
		      ];
  }
  $mapped_memberq->execute($unigene_id);
  while(my ($clone_id, $marker_id) = $mapped_memberq->fetchrow_array()) {
    my $marker=CXGN::Marker->new($dbh,$marker_id);
    my $marker_name='Unknown';
    if($marker)
    {
        $marker_name=$marker->name_that_marker();
    }
    push @mapped, [ qq|<a href="/search/est.pl?request_id=$clone_id&request_from=1&request_type=8">SGN-C$clone_id</a>|,
		    qq|<a href="/search/markers/markerinfo.pl?marker_id=$marker_id">$marker_name</a>|
		  ];
  }

  my $microarray_resources_html =
    @microarray ? columnar_table_html( headings => [qw/ SGN-C  SGN-E  Dir.  Chip  SpotID  Order Info/],
				       data     => \@microarray,
				     )
                : qq|<span class="ghosted">No aligned sequences in this unigene are on any microarray</span>|;

  my $mapped_html =
    @mapped ? columnar_table_html( headings => [ 'EST', 'Marker' ],
				   data     => \@mapped,
				 )
            : qq|<span class="ghosted">No member sequence or clone is mapped.</span>|;

  my $feature_content = info_table_html( 'Microarray Resources' => $microarray_resources_html,
					 'Marker Information'   => $mapped_html,
					 __border               => 0,
				       );

#manual annotation section - data collection
#inserted 2003-09-17 by Dan
#trying to keep koni-style syntax for consistency
#################################################

    my $manual_annot_content = "";
  $manual_annotq->execute($unigene_id) or $page->error_page("Couldn't execute manual_annotq with unigene $unigene_id");
  while (my ($author_name, $date_entered, $date_modified, $annot_text, $clone_name, $clone_id) = $manual_annotq->fetchrow_array()){
      $manual_annot_content = <<EOH;
      <table width="100%">
        <tr><td align="left">Based on clone <a href="/search/est.pl?request_type=8&request_id=$clone_id&request_from=1">$clone_name</a>, annotated by <b>$author_name</b></td><td align="right">Created $date_entered, last modified $date_modified</td>
        </tr>
        <tr><td align="left" colspan="2">$annot_text</td></tr>
     </table>
EOH
  }

$manual_annot_content ||= qq{<span class="ghosted">There are currently no manually curated annotations attached to this unigene or any of its constituent ESTs.</span>};
# # if ($manual_annot_content eq "") {
# #   $manual_annot_content = 
# # } else {
# #   $manual_annot_content = "<tr><td><table cellpadding=0 cellspacing=0 border=0 width=100% align=center>" . $manual_annot_content ."</table></td></tr>";
# }

#################################################


#library representation section - data collection
#Dan, 2003-10-29
#################################################

   my %lib_rep=();
   $library_repq->execute($unigene_id) or $page->error_page("Couldn't execute library_repq with unigene $unigene_id: $DBI::errstr");
   while (my ($count, $lib_id, $lib_name, $lib_tissue, $lib_devstage, $org) = $library_repq->fetchrow_array()){
 #format organism name for display
     $org = abbr_latin($org);
     @{$lib_rep{$lib_id}} = ($org, $lib_name, $lib_tissue, $lib_devstage, $count);
   }

  my @lib_rep_content = ();
  foreach (sort {$lib_rep{$b}[4] <=> $lib_rep{$a}[4]} (keys %lib_rep)){

    push @lib_rep_content,[$lib_rep{$_}[1],
			   qq|<div align="left">$lib_rep{$_}[0] $lib_rep{$_}[2]</div>|,
			   $lib_sizes{$_},
			   $lib_rep{$_}[4],
			  ];
  }

  my $lib_rep_content;
  unless (@lib_rep_content) {
    $lib_rep_content = <<EOH;
  <span class="ghosted">Error:  No library representation found</span>
EOH
  } else {
    $lib_rep_content = columnar_table_html(headings => ['Library',
							'Description',
							'Library size (#&nbsp;ESTs)',
							'ESTs in this unigene',
						       ],
					   data     => \@lib_rep_content,
					  );
   }

#################################################


  my $blast_content = qq|<table width="100%">|;
  $blastq->execute($unigene_id);
  while(my ($blast_annotation_id, $blast_target_id, $blast_program,
	    $target_dbname, $n_hits) = $blastq->fetchrow_array()) {
    if ($n_hits > 0) {
      $blast_content .= qq|<tr><td align="left"><b>$target_dbname [$blast_program]</b></td>
<td align="right" colspan="5"> Showing best match of $n_hits recorded 
[<a href="/search/unigene-all-blast-matches.pl?unigene_id=$unigene_id&amp;l=$unigene_length&amp;t=$blast_target_id" target="blank">
Show All</a>]</td></tr>|;
      $blast_hitq->execute($blast_annotation_id);
      my $limit = 1; #it's faster to do our own limit here
      while (my ($match_id, $evalue, $score, $identity, $start, $end, $defline) = $blast_hitq->fetchrow_array() and $limit--) {
	$match_id = link_identifier($match_id) || $match_id;
	if (length($defline)>100) {
	  $defline = substr($defline, 0, 97) . '&hellip;';
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
    } else {
      $blast_content .= qq{<tr><td align="left"><b>$target_dbname [$blast_program]</b></td><td align="right" colspan="5"><span class="ghosted">No significant hits detected for this target</span></td></tr>};
    }
    $blast_content .= qq{<tr><td colspan="6"><br /></td></tr>};
  }


  if ($blast_content eq "") {
    $blast_content .= qq{<tr><td class="center"><span class="ghosted">No BLAST annotations have been pre-computed for this sequence. Please try our <a href="/tools/blast/?preload_id=$unigene_id&preload_type=15">online BLAST service</a>.</td></tr>};
  }

  $blast_content .= "</table>";




# marker matches
############################################
my $marker_match='';
my $marker_sth = $dbh->prepare("select distinct m.marker_id, alias from primer_unigene_match inner join marker as m using(marker_id) inner join marker_alias using (marker_id) where unigene_id=? and preferred='t'");
$marker_sth->execute($unigene_id);
while(my $row = $marker_sth->fetchrow_hashref())
{
    $marker_match .= qq{<a href="/search/markers/markerinfo.pl?marker_id=$row->{marker_id}">$row->{alias}</a><br />};
}







#begin COSII marker section inserted by john. 
#############################################
my $cosii_content='';
my $other_possible_sgn_id=CXGN::Unigene::Tools::sgn_id_to_cgn_id($dbh,$unigene_id);
my $other_sgn_id_clause='';
if($other_possible_sgn_id)
{
    $other_sgn_id_clause=" or unigene_id=$other_possible_sgn_id";
}
my $sth=$dbh->prepare("select marker_id,alias from cosii_ortholog inner join marker using (marker_id) inner join marker_alias using (marker_id) where preferred='t' and (unigene_id=? $other_sgn_id_clause)");
$sth->execute($unigene_id);
while(my ($marker_id,$marker_name)=$sth->fetchrow_array())
{
    $cosii_content.="COSII marker <a href=\"/search/markers/markerinfo.pl?marker_id=$marker_id\">$marker_name</a> was created with this unigene.<br />\n";
}
###########################################
#end COSII marker section inserted by john. 


















##ESTScan predicted peptides
##inserted June 30, 2005 by Chenwei
##trying to keep koni-style syntax for consistency
###################################################

  my $estscan_pep_content = "";
  my $estscan_pep;
  $estscan_pepq->execute($unigene_id) or $page->error_page("Couldn't execute estscan_pepq with unigene $unigene_id");
  $signalpq->execute($unigene_id) or $page->error_page("Something wrong with SignalP query for unigene $unigene_id");
  if (($estscan_pep) = $estscan_pepq->fetchrow_array()){
    if ($estscan_pep eq "NULL"){
      $estscan_pep_content = 'No coding sequence identified.  Most probably this unigene contains only UTR.';
    }
    else {
		my $row = $signalpq->fetchrow_hashref;
      my $i=0;
      my $estscan_pep_display = '';
	  	my ($nn_d, $nn_ypos, $nn_score) = ($row->{nn_d}, $row->{nn_ypos}, $row->{nn_score});
		if($nn_d eq 'Y') { $estscan_pep_display .= "<span style='color:green'>"; }
		while ((length($estscan_pep) - $i)>90) {
			if($nn_d eq 'Y' and $i==0) {
				$estscan_pep_display .= substr($estscan_pep, 0, $nn_ypos-1) . "</span>" . substr($estscan_pep, $nn_ypos-1, 90-$nn_ypos+1) . "<br />\n";
			}
			else {
				$estscan_pep_display .= substr($estscan_pep, $i, 90) . "<br />\n";
			}
			$i += 90;
		}
      $estscan_pep_display .= substr($estscan_pep, $i) . "\n";
      $estscan_pep_content .=qq|<div class="fix" align="left">$estscan_pep_display</div>\n|;
	if($nn_d){
		$estscan_pep_content .= "<br />\n<div style='text-align:left'>";
	  if($nn_d eq 'Y'){
	  	$estscan_pep_content .= "SignalP predicts <b>secretion</b> with a score of $nn_score";
	  }
	  elsif($nn_d eq 'N') {
	  	$estscan_pep_content .= "SignalP predicts non-secretion with a score of $nn_score";
	  }
		$estscan_pep_content .= "</div>";	  
	}
      $estscan_pep_content .=qq|[<a style="line-height: 2" href="unigene-estscan-detail.pl?unigene_id=$unigene_id" target="blank">Show ESTScan Detail</a>]|;
    }
  }
  else {
    $estscan_pep_content = '<span class="ghosted">Not processed with ESTScan.</span>';
  }
  $estscan_pep_content = <<EOH;
<div>
$estscan_pep_content
</div>
EOH

##SignalP predicted signal peptide
# Relies on protein sequence from ESTScan

	


########################################
#InterPro domain annotation.  Added by Chenwei 06/2005
  my %domain_matches_description = ();
  $iprq->execute($unigene_id) or $page->error_page("Couldn't execute iprq with unigene $unigene_id");
  while (my ($ipr_accession, $ipr_description) = $iprq->fetchrow_array()){
    $domain_matches_description{$ipr_accession}= $ipr_description;
  }

  #retrieve hit domains.  
  my %domain_matches_seq = ();
  $dmq->execute($unigene_id) or $page->error_page("Couldn't execute dmq with unigene $unigene_id");
  while (my($ipr_accession, $start, $end) = $dmq->fetchrow_array()) {
    if (!defined $domain_matches_seq{$ipr_accession}) {
      $estscan_pep =~ s/(\\)//g;
      $estscan_pep =~ s/[A-Z]/-/gi; #first generate a sequence of all '-'
      $domain_matches_seq{$ipr_accession} = $estscan_pep;
    }

    #skip start and end coords that don't make sense
    next unless $start <= $end && $start >= 0 && $end < length($estscan_pep);

    my $replace = 'X'x($end - $start + 1);
    substr($domain_matches_seq{$ipr_accession}, $start - 1, $end - $start + 1) = $replace; ##replace the match domains with 'X', so that the domains an be displayed with Alignment.pm
  }

  

  my $ipr_content = "";
  if(%domain_matches_description) {

    #Generate an align object
  my $domain_align = CXGN::Alignment::align->new(
						 align_name=>'ipr', 
						 width=>500, 
						 height=>2000, 
						 type=>'pep'
						);
  foreach (keys %domain_matches_seq) {
    my $len = length $domain_matches_seq{$_};
    my $member = CXGN::Alignment::align_seq->new(
						 horizontal_offset=>0,
						 vertical_offset=>0,
						 length=>400,
						 height=>15,
						 start_value=>1, 
						 end_value=>$len, 
						 id=>$_, 
						 seq=>$domain_matches_seq{$_}, 
						 species=>' '
						);
    $domain_align -> add_align_seq($member);
  }

  #Render image
  my $tmp_image = new File::Temp(
				 DIR => $basepath . $tmpdir,
				 SUFFIX => '.png',
				 UNLINK => 0,
                              );
  close $tmp_image;
  $domain_align -> render_png_file($tmp_image, 'a');
  $tmp_image =~ s/$basepath//;

    $ipr_content = qq|<ul style="list-style: none">\n|;
    foreach (keys %domain_matches_description){
      $ipr_content .= qq|<li><a href="http://srs.ebi.ac.uk/srsbin/wgetz?%5Binterpro-AccNumber:$_%5D+-e" target="blank">$_</a>&nbsp;&nbsp;$domain_matches_description{$_}</li>\n|;
    }
    $ipr_content .= "</ul>\n";
    $ipr_content .= "<center><img src=\"$tmp_image\" alt=\"\" /></center>\n";
  } else {
    $ipr_content = '<span class="ghosted">No InterPro domain matches.</span>'
  }


#########################################
#GO annotation.  Added by Chenwei 06/2005
  my %go_matches = ();
  $goq->execute($unigene_id) or $page->error_page("Couldn't execute goq with unigene $unigene_id");
  while (my ($go_accession, $go_description) = $goq->fetchrow_array()){
    $go_matches{$go_accession}= $go_description;
  }

  my $go_content = "";
  if(%go_matches) {
    $go_content = qq|<ul style="list-style: none">\n|;
    foreach (keys %go_matches){
      $go_content .= qq|<li><a href="http://www.ebi.ac.uk/ego/DisplayGoTerm?id=GO:$_" target="blank">GO:$_</a> $go_matches{$_}</li>|;
    }
    $go_content .= "</ul>\n";
  } else {
    $go_content = '<span class="ghosted">No InterPro gene ontology annotation</span>';
  }

########################################
#Gene family information.  Added by Chenwei 08/2005
#  $family_group_q->execute($unigene_id);
	my $family_content = "";
	my $family_count = 0;
	$family_content = qq|<table width="100%">\n|;
	$family_content .= qq|<tr align="center"><th style="white-space: nowrap">Family Build<br />(I value*)</th><th>Build Status</th><th>Family&nbsp;id</th><th>Annotation**</th><th># Family Members</th></tr>|;
	$family_q->execute($unigene_id);
	while (my ($ivalue, $family_id, $annotation, $status) = $family_q->fetchrow_array()){
		my $row_style = "";
		if($status eq 'C'){$status = "Current"} else{$status = "Outdated";$row_style="color:#555"}
		$family_member_q->execute($family_id);
		my ($count) = $family_member_q->fetchrow_array();
		$family_content .= qq|<tr align="center" style="$row_style"><td>$ivalue</td><td>$status</td><td><a href="family.pl?family_id=$family_id">$family_id</a></td><td align="left">$annotation</td><td>$count</td><tr>|;
		$family_count++;
	} 
	$family_content .= "</table>\n*i value: controls inflation, a process to dissipate family clusters.  At high i value, genes tend to be separated into different families.<br />**Annotation:  the most common InterPro annotation(s) of the Arabidopsis members in the family.<br /><br />";
	$family_content = "<span class=\"ghosted\">Unigene was not found to be a member of any known family</span>" unless $family_count > 0; 
  $page->header();

# This commented out from below as it's not ready for production yet
#      <tr><td $section_header><b>Library Representation</b></td></tr>
#  $lib_rep_content

  print page_title_html("Unigene SGN-U$unigene_id");

  if($unigene_buildstatus ne 'C') {
  	print "<center>$deprecate_content</center>";
  }
  print blue_section_html('Unigene sequence',$unigene_content);
  print blue_section_html('From libraries',$lib_rep_content);
  print blue_section_html('Member sequences',$alignment_content);
  print blue_section_html('Mapped sequences and microarray resources',$feature_content);
  print blue_section_html('Manual annotations',$manual_annot_content);
  print blue_section_html('BLAST annotations',$blast_content);
  print blue_section_html('Marker BLAST hits',$marker_match) if $marker_match;
  if($cosii_content){print blue_section_html('Associated COSII marker',$cosii_content);}
  print blue_section_html('ESTScan predicted peptide',$estscan_pep_content);
  if ( defined $estscan_pep && $estscan_pep ne "NULL" ){
    print blue_section_html('Interpro domain annotations',$ipr_content);
    print blue_section_html('Gene ontology annotations',$go_content);
    print blue_section_html('Gene family',$family_content);
  } else {
    print blue_section_html('Interpro domain annotations','<span class="ghosted">None</span>');
    print blue_section_html('Gene ontology annotations','<span class="ghosted">None</span>');
    print blue_section_html('Gene family','<span class="ghosted">None</span>');
  }
  if($preceding_content) {print blue_section_html('Preceding Unigenes', $preceding_content);}
  $page->footer();
  exit(0);
}

sub not_found {
  my ($page, $id) = @_;

  $page->header();

  print <<EOF;

  <p>No information found for unigene SGN-U$id.</p>
  <br />
  <br />
EOF
  $page->footer();
  exit 0;
}

sub legacy_not_found {
  my ($page, $build_id, $cluster, $contig) = @_;

  $page->header();

  print <<EOF;

  <p>No information found for legacy search build \"$build_id\", cluster \"$cluster\", contig \"$contig\".</p>
  <br />
  <br />
EOF
  $page->footer();
  exit 0;
}

sub empty_search {
  my ($page, $unigene_id) = @_;

  $page->header();

  print <<EOF;

  <b>No unigene search criteria specified</b>

EOF

  $page->footer();
  exit 0;
}


sub invalid_search {
  my ($page, $unigene_id) = @_;

  $page->header();

  print <<EOF;

  <b>The specified unigene identifer ($unigene_id) does not result in a valid search.</b>

EOF

  $page->footer();
  exit 0;
}

sub prep_random_search {

  my $dbh = CXGN::DB::Connection->new();
  my $ruq = $dbh->prepare("select unigene_id from unigene LEFT JOIN unigene_build USING (unigene_build_id) where unigene_build.status='C' and nr_members>1 order by random() limit 1000");
  $ruq->execute();
  while(my ($unigene_id) = $ruq->fetchrow_array()) {
    push @random_unigene_ids, $unigene_id;
  }

}

