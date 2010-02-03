
use strict;

use CGI qw/-compile :standard/;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ info_section_html info_table_html columnar_table_html page_title_html html_break_string /;
use CXGN::Tools::Identifiers qw/link_identifier/;
use CXGN::Transcript::Unigene;
use CXGN::Transcript::UnigeneBuild;
use CXGN::Transcript::Library;
use CXGN::Transcript::EST;
use CXGN::Transcript::CDS;
use CXGN::Phylo::Alignment;
use CXGN::Phylo::Alignment::Member;
use CXGN::Phenome::Locus;
use CXGN::Marker;

my $page = CXGN::Page->new("SGN unigene detail page", "Lukas");
my ($unigene_id, $force_image, $random, $highlight) = $page->get_encoded_arguments("unigene_id", "force_image", "random", "highlight");

if (!$unigene_id && !$random) { empty_search($page, $unigene_id); }
    

my $dbh = CXGN::DB::Connection->new();

my $u = undef;

# create a random unigene if requested
if ($random) { 
    $u = CXGN::Transcript::Unigene->new_random($dbh);

}
else { 
    $u = CXGN::Transcript::Unigene->new($dbh, $unigene_id);

}
$unigene_id = $u->get_unigene_id(); # unigene_id may have been cleaned in subtle ways by constructor...

my $vhost_conf = CXGN::VHost->new();
my $basepath = $vhost_conf->get_conf('basepath');
my $tmpdir = File::Spec->catdir($vhost_conf->get_conf('tempfiles_subdir'),
				'unigene_images'
			       );


my $build_nr = $u->get_build_nr();
my $build_id = $u->get_build_id();
my $sequence = $u->get_sequence();
my $seq_display = html_break_string($sequence,90);
my $nr_members = $u->get_nr_members();

my $unigene_build = CXGN::Transcript::UnigeneBuild->new($dbh, $build_id);
my $build_date = $unigene_build->get_build_date();
my $org_group_name = $unigene_build->get_organism_group_name();




###
### Deprecation information
###

my $deprecate_content = "";

#$deprecate_content = "BUILD STATUS: ".$unigene_build->get_status()."\n<br />";


if ($unigene_build->get_status() ne 'C') { 
 #   $deprecate_content .= "NOT CURRENT!<br />\n";
    my @updated_unigene = $u->get_current_unigene_ids($unigene_id);
    if (@updated_unigene) { 

	#$deprecate_content .="update unigenes are avaialble<br />\n";
    	#Check to see if unigene is up to date, and find the updated unigene if it is not.  We will want to display this before the "unigene_content" 
	#but this content relies on the $org_group_name and $build_nr from the meta-query
    
	$deprecate_content .= "<div style='text-align:center; padding:3px; margin-left:5px;
								margin-bottom:10px; font-size:14px; border:1px dashed #772222; 
								background-color:#e5e5e5;'>";
	$deprecate_content .= "<span style=color:#660000'>This unigene is from an out-of-date build, <em>$org_group_name #$build_nr</em></span>";	
	    my ($new_build_organism, $new_build_nr) = $unigene_build->get_superseding_build_info();
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
	    $deprecate_content .= "</div>";
    }
    
    
}


###
### Sequence and basic unigene info section
###

my $database_name = $u->get_alternate_namespace();
my $sequence_name = $u->get_alternate_identifier();
my $sequence_content = <<HTML;

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

HTML


###
### Associated SGN loci
###

# (Lukas, October 2007)

my @associated_loci = $u->get_associated_loci('f');
my $associated_loci_content = "";
my @loci_table = ();

if (@associated_loci) { 
    foreach my $locus (@associated_loci) { 
	if ($locus->get_obsolete() ne 't') { # don't display obsolete loci
	    my $locus_id = $locus->get_locus_id();
	    my $locus_symbol = $locus->get_locus_symbol();
	    my $link = qq { <a href="/phenome/locus_display.pl?locus_id=$locus_id">$locus_symbol</a> };
	    push @loci_table, [ $link, $locus->get_locus_name() ];
	}				    
	
	$associated_loci_content = columnar_table_html( headings=> [ "Locus symbol", "Locus name" ],
							data => \@loci_table,
							);	
    }
}
else {
    # just leave it empty. info_section will print "none" in the blue bar. nice!
    #$associated_loci_content = qq { <span class="ghosted">No loci are associated to this unigene</span> };
}



###
### Library Info
###

my @library_ids = $u->get_member_library_ids();

my @lib_rep_content = ();
my $lib_rep_content = "";

#$lib_rep_content .= "MY LIBRARY_IDS = ".(join "|",@library_ids)."<br />\n";
foreach my $lid (@library_ids) { 
    my $library = CXGN::Transcript::Library->new($dbh, $lid);

    my $organism_id = $library->get_organism_id();
    my $organism = $library->get_organism_name();
    my $library_name = $library->get_library_shortname();
    my $tissue = $library->get_tissue();
    my $dev_stage = $library->get_development_stage();
    my $lib_clone_count = $library->get_clone_count();
    my $unigene_member_count = $u->get_unigene_member_count_in_library($library->get_library_id());
    
 #   $lib_rep_content .= "$library_name, $tissue, $dev_stage, $unigene_member_count<br />\n";


    push @lib_rep_content,[$library_name,
			   qq|<div align="left">$organism $tissue</div>|,
			   $lib_clone_count,
			   $unigene_member_count,
			  ];
    

}
unless (@lib_rep_content) {
    $lib_rep_content = <<EOH;
    <span class="ghosted">Error:  No library representation found</span>
EOH
  

} else {
    $lib_rep_content .= columnar_table_html(headings => ['Library',
							'Description',
							'Library size (#&nbsp;ESTs)',
							'ESTs in this unigene',
							],
					   data     => \@lib_rep_content,
					   );
}


#$content .= $lib_rep_content;

###
### Unigene member information section
###

my @highlight = split / /, $highlight;
my $alignment_image_html = $u -> get_unigene_member_image(\@highlight, $force_image);




###
### microarray stuff
###

my @microarray = ();
my @microarray_data = $u->get_microarray_info();
foreach my $md (@microarray_data) { 
#while(my ($clone_id, $est_id, $read_dir, $chip_name, $release, $version, $spot_id, 
	#  $content_specific_tag) = $microarrayq->fetchrow_array()) {
    
    if (!defined($md->{read_dir})) {
	$md->{read_dir} = "<span class=\"ghosted\">Unknown</span>";
    } elsif ($md->{read_dir} eq "+") {
	$md->{read_dir} = "5'";
    } else {
	$md->{read_dir} = "3'";
    }
    
    push @microarray, ["SGN-C$md->{clone_id}",
		       qq|[<a href="/search/est.pl?request_id=$md->{est_id}&request_from=1&request_type=7">SGN-E$md->{est_id}</a>]|,
		       $md->{read_dir},
		       $md->{chip_name},
		       "$md->{release}-$md->{version}-$md->{spot_id}-$md->{content_specific_tag}",
		       qq|[<a href="http://bti.cornell.edu/CGEP/CGEP.html">Order&nbsp;Array</a>]|,
		       qq|[<a href="http://ted.bti.cornell.edu/cgi-bin/array/basicsearch.cgi?arrayID=$md->{release}-$md->{version}-$md->{spot_id}">TMD</a>]|,
		       ];
}

###
### Genetically mapped unigenes
###

#  $mapped_memberq->execute($unigene_id);
#  while(my ($clone_id, $marker_id) = $mapped_memberq->fetchrow_array()) {

my @mapped_member_ids = $u -> get_mapped_members();
my @mapped = ();
foreach my $info (@mapped_member_ids) { 
    my $marker=CXGN::Marker->new($dbh, $info->{marker_id});
    my $marker_name='Unknown';
    if($marker)
    {
        $marker_name=$marker->name_that_marker();
    }
    push @mapped, [ qq|<a href="/search/est.pl?request_id=$info->{clone_id}&request_from=1&request_type=8">SGN-C$info->{clone_id}</a>|,
		    qq|<a href="/search/markers/markerinfo.pl?marker_id=$info->{marker_id}">$marker_name</a>|
		    ];
}


# # marker matches
# ############################################
# my $marker_match='';
# my $marker_sth = $dbh->prepare("select distinct m.marker_id, alias from primer_unigene_match inner join marker as m using(marker_id) inner join marker_alias using (marker_id) where unigene_id=? and preferred='t'");
# $marker_sth->execute($unigene_id);
# while(my $row = $marker_sth->fetchrow_hashref())
# {
#     $marker_match .= qq{<a href="/search/markers/markerinfo.pl?marker_id=$row->{marker_id}">$row->{alias}</a><br />};
# }


#begin COSII marker section inserted by john. 
#############################################
my $cosii_content='';
my $other_possible_sgn_id=CXGN::Unigene::Tools::sgn_id_to_cgn_id($dbh,$unigene_id);
#my $other_sgn_id_clause='';
#if($other_possible_sgn_id)
#{
#    $other_sgn_id_clause=" or unigene_id=$other_possible_sgn_id";
#}

my @cosii = $u->get_cosii_info();
foreach my $c (@cosii) { 
    my ($marker_id,$marker_name)=@$c;
    {
	$cosii_content.="COSII marker <a href=\"/search/markers/markerinfo.pl?marker_id=$marker_id\">$marker_name</a> was created with this unigene.<br />\n";
    }
}
###########################################
#end COSII marker section inserted by john. 




###
### microarray data
###

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



###
### manual annotation section - data collection
###

my $manual_annot_content = "";
my @manual_annotation_list = $u->get_manual_annotations();
foreach my $l (@manual_annotation_list) { 
    my ($author_name, $date_entered, $date_modified, $annot_text, $clone_name, $clone_id) = @$l;
    $manual_annot_content = <<EOH;
    <table width="100%">
        <tr><td align="left">Based on clone <a href="/search/est.pl?request_type=8&request_id=$clone_id&request_from=1">$clone_name</a>, annotated by <b>$author_name</b></td><td align="right">Created $date_entered, last modified $date_modified</td>
        </tr>
        <tr><td align="left" colspan="2">$annot_text</td></tr>
	</table>
EOH
}

#$manual_annot_content ||= qq{<span class="ghosted">There are currently no manually curated annotations attached to this unigene or any of its constituent ESTs.</span>};

###
### BLAST annotations
###

my $blast_content = qq|<table width="100%">|;

my %annotations = ();
@{$annotations{arabidopsis}} = $u->get_arabidopsis_annotations();
@{$annotations{genbank}}  = $u->get_genbank_annotations();

my $blast_program = "blastx"; # FIX ME
my $unigene_length = length($u->get_sequence());
foreach my $target_dbname ("genbank", "arabidopsis") { 
    my $blast_target_id = $annotations{$target_dbname}->[0];
    my $n_hits = @{$annotations{$target_dbname}};
    if ($n_hits > 0) {
	$blast_content .= qq|
	    <tr><td align="left"><b>$target_dbname [$blast_program]</b></td>
	    <td align="right" colspan="5"> Showing best match of $n_hits recorded 
	    [<a href="/search/unigene-all-blast-matches.pl?unigene_id=$unigene_id&amp;l=$unigene_length&amp;t=$blast_target_id" target="blank">
	     Show All</a>]</td></tr>|;
	
	# only show the first match...
	#
	my $annot = (@{$annotations{$target_dbname}})[0]; 
	(my ($blast_target_id, $match_id, $evalue, $score, $identity, $start, $end, $defline)) = @$annot;
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
 
     } else {
	 $blast_content .= qq{<tr><td align="left"><b>$target_dbname [$blast_program]</b></td><td align="right" colspan="5"><span class="ghosted">No significant hits detected for this target or not run</span></td></tr>};
	 
	 $blast_content .= qq{<tr><td colspan="6"><br /></td></tr>};
     }
    
    
    if ($blast_content eq "") {
	$blast_content .= qq{<tr><td class="center"><span class="ghosted">No BLAST annotations have been pre-computed for this sequence. Please try our <a href="/tools/blast/?preload_id=$unigene_id&preload_type=15">online BLAST service</a>.</td></tr>};
    }
}    
    
$blast_content .= "</table>";


###
### ESTScan predicted peptides
###

##inserted June 30, 2005 by Chenwei

my $protein_content = "";

#my $cds = CXGN::Transcript::CDS->new_with_unigene_id($dbh, $unigene_id);
my @cds = $u->get_cds_list();

my $protein = "";


foreach my $c (@cds) { 
    $protein  = $c->get_protein_seq();
    my $cds = $c->get_cds_seq();
    my $direction = $c->get_direction();
    my $method = $c->get_method();
    my $frame = undef;
    my $score = undef;
    if ($method eq "estscan") { 
	$score=$c->get_score();
    }
    else { 
	$frame = $c->get_frame();
    }

    if (!$protein){
	$protein_content = 'No coding sequence identified.  Most probably this unigene contains only UTR.';
    }
    else {
	my $method_text = "longest six frame translation";
	if ($method eq "estscan") { 
	    $method_text = "ESTScan";
	    $method_text .=qq| [<a style="line-height: 2" href="unigene-estscan-detail.pl?unigene_id=$unigene_id" target="blank">Show ESTScan Detail</a>]|;
	    
	}
	$protein_content .= ">Prediction based on <b>$method_text</b>\n <br />";
	my $i=0;
	my $protein_display = '';
	my ($nn_d, $nn_ypos, $nn_score) = $c->get_signalp_info();
	if($nn_d eq 'Y') { $protein_display .= "<span style='color:green'>"; }
	while ((length($protein) - $i)>90) {
	    if($nn_d eq 'Y' and $i==0) {
		$protein_display .= substr($protein, 0, $nn_ypos-1) . "</span>" . substr($protein, $nn_ypos-1, 90-$nn_ypos+1) . "<br />\n";
	    }
	    else {
		$protein_display .= substr($protein, $i, 90) . "<br />\n";
	    }
	    $i += 90;
	}
	$protein_display .= substr($protein, $i) . "\n";
	$protein_content .=qq|<div class="fix" align="left">$protein_display</div>\n|;
	if($nn_d){
	    $protein_content .= "<br />\n<div style='text-align:left'>";
	    if($nn_d eq 'Y'){
		$protein_content .= "SignalP predicts <b>secretion</b> with a score of $nn_score";
	}
	    elsif($nn_d eq 'N') {
		$protein_content .= "SignalP predicts non-secretion with a score of $nn_score";
	    }
	    $protein_content .= "</div>";	  
	}
	if (!$nn_d) { 
	    $protein_content .="<br /><span class=\"ghosted\">SignalP analysis not run for this sequence.</span>";
	}
    }




    $protein_content = <<EOH;
    <div>
	$protein_content
	</div>
EOH



##SignalP predicted signal peptide
# Relies on protein sequence from ESTScan

	
###
### Interpro domains
###

# InterPro domain annotation.  Added by Chenwei 06/2005

#my %domain_matches_description = ();

#while (my ($ipr_accession, $ipr_description) = $iprq->fetchrow_array()){
#    $domain_matches_description{$ipr_accession}= $ipr_description;
#}
    
    my $ipr_content = "";
    
    my @interpro_domain_matches = $c->get_interpro_domains();
    
    my %domain_matches_seq = ();
    my %domain_matches_description = ();
    foreach my $idm (@interpro_domain_matches) { 

	my($ipr_accession, $ipr_description, $start, $end) = @$idm;

	$domain_matches_description{$ipr_accession}=$ipr_description;
	if (!defined $domain_matches_seq{$ipr_accession}) {
	    $protein =~ s/(\\)//g;
	    $protein =~ s/[A-Z]/-/gi; #first generate a sequence of all '-'
	    $domain_matches_seq{$ipr_accession} = $protein;
	}
	
	#skip start and end coords that don't make sense
	next unless $start <= $end && $start >= 0 && $end < length($protein);
	
	my $replace = 'X'x($end - $start + 1);
	substr($domain_matches_seq{$ipr_accession}, $start - 1, $end - $start + 1) = $replace; ##replace the match domains with 'X', so that the domains an be displayed with Alignment.pm
    }
    
  
    if(%domain_matches_description) {
	
	#Generate an align object
	my $domain_align = CXGN::Phylo::Alignment->new(
						       align_name=>'ipr', 
						       width=>500, 
						       height=>2000, 
						       type=>'pep'
						       );
	foreach (keys %domain_matches_seq) {
	    my $len = length $domain_matches_seq{$_};
	    my $member = CXGN::Phylo::Alignment::Member->new(
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
	    $domain_align -> add_member($member);
	}
	
	#Render image
	my $tmp_image = new File::Temp(
				       DIR => File::Spec->catfile($basepath,$tmpdir),
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
	$ipr_content = '<br /><span class="ghosted">No InterPro domain matches or not analyzed.</span><br /><br />';
    }

    $protein_content .=$ipr_content;
}

if (!@cds) { 
    $protein_content = '<span class="ghosted">No protein sequence available.</span>';
}



###
### GO Annotations
###

# Added by Chenwei 06/2005

my %go_matches = ();
#  $goq->execute($unigene_id) or $page->error_page("Couldn't execute goq with unigene $unigene_id");
#  while (my ($go_accession, $go_description) = $goq->fetchrow_array()){

my @go_annotations = $u->gene_ontology_annotations();
foreach my $go (@go_annotations) { 
    my ($go_accession, $go_description) = @$go;
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
    $go_content = ""; #'<span class="ghosted">No InterPro gene ontology annotation</span>';
}



###
### Gene family information 
###

# (originally added by Chenwei, 08/2005, slightly refactored, Lukas 9/2007)


my $family_content = family_html($u);
###
### Unigenes in preceding builds
###

	## Find out if there is a preceding build.  If there is such a build, find the preceding unigenes and fill the preceding_content
my $preceding_content = "";
my @preceding_unigene_content = ();	
my $preceding_build_name = "";
my $preceding_build_nr = "";

my @preceding_unigene_ids = $u->get_preceding_unigene_ids();

if (@preceding_unigene_ids) { 
    foreach my $uid (@preceding_unigene_ids){
	my $preceding_u = CXGN::Transcript::Unigene->new($dbh, $uid);
	my $preceding_build = CXGN::Transcript::UnigeneBuild->new($dbh, $preceding_u->get_build_id());
	$preceding_build_name = $preceding_build->get_organism_group_name();
	my $preceding_build_nr = $preceding_build->get_build_nr();
	if ($uid) { 
	    push(@preceding_unigene_content, ["<a href=\"unigene.pl?unigene_id=SGN-U$uid\">SGN-U$uid</a>", "$preceding_build_name #$preceding_build_nr"]);
		
	    }
    }
    
    $preceding_content = columnar_table_html(headings => ['Unigene', 'Build'], data=> \@preceding_unigene_content); 

}
else {
    $preceding_content = ""; #"<span class='ghosted'>None in previous build: $preceding_build_name #$preceding_build_nr</span>";   
    
}




###
### Output page, finally!
###

$page->header("SGN Unigene SGN-U$unigene_id");

my $content = page_title_html("Unigene SGN-U$unigene_id");

$content .= $deprecate_content;
$content .= info_section_html(title=>"Sequence", contents=>$sequence_content);
$content .= info_section_html(title=>"Associated Loci", contents=>$associated_loci_content);
$content .= info_section_html(title=>"Library representation", contents=>$lib_rep_content);
$content .= info_section_html(title=>"Member sequences", contents=>$alignment_image_html);
$content .= info_section_html(title=>"Microarray", contents=>$feature_content);
$content .= info_section_html(title=>"Associated COSII markers", contents=>$cosii_content);
$content .= info_section_html(title=>"Manual Annotations", contents=>$manual_annot_content);
$content .= info_section_html(title=>"BLAST Annotations", contents=>$blast_content);
$content .= info_section_html(title=>"Predicted Protein Sequences", contents=>$protein_content);
#$content .= info_section_html(title=>"Interpro domains", contents=>$ipr_content);
$content .= info_section_html(title=>"GO Annotations", contents=>$go_content);
$content .= info_section_html(title=>"Gene Families", contents=>$family_content);
$content .= info_section_html(title=>"Sequences from preceding builds", contents=>$preceding_content);

print $content;

$page->footer();


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

sub family_html {
    my ($unigene) = @_;

    my @f = $u->get_families
        or return '';


    return columnar_table_html( headings => ['Family Build<br />(I value*)','Family ID', 'Annotation**','# Members'],
                                data =>
                                [
                                 map {
                                     my ($family_id, $ivalue, $annotation, $count) = @$_;
                                     [$ivalue,a({href=> "family.pl?family_id=$family_id"},$family_id),$annotation,$count],
                                 } @f
                                ],
                              )
        .<<EOHTML;
*i value: controls inflation, a process to dissipate family clusters. At high i value, genes tend to be separated into different families.<br />
**Annotation: the most common InterPro annotation(s) of the Arabidopsis members in the family.
EOHTML

}

# sub prep_random_search {

#   my $dbh = CXGN::DB::Connection->new();
#   my $ruq = $dbh->prepare("select unigene_id from unigene LEFT JOIN unigene_build USING (unigene_build_id) where unigene_build.status='C' and nr_members>1 order by random() limit 1000");
#   $ruq->execute();
#   while(my ($unigene_id) = $ruq->fetchrow_array()) {
#     push @random_unigene_ids, $unigene_id;
#   }

# }
