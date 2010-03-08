use strict;
use CXGN::Page;
use CXGN::Marker;
use CXGN::Genomic::Clone;
use CXGN::Page::FormattingHelpers qw/ blue_section_html page_title_html html_break_string newlines_to_brs html_optional_show columnar_table_html info_table_html /;
use CXGN::Metadata;
use CXGN::People::PageComment;
use CXGN::DB::Connection;
use CXGN::Accession;
use CXGN::Accession::Tools;
use SGN::Controller::Marker;
use CXGN::Map;
use CXGN::Cview::ChrMarkerImage;
use CXGN::Cview::MapFactory;
use CXGN::Unigene::Tools;
my $dbh=CXGN::DB::Connection->new();
my $page=CXGN::Page->new("markerinfo.pl","john and beth");
$page->jsan_use('MochiKit.Base', 'MochiKit.Async');
my($marker_id,$id,$name)=$page->get_encoded_arguments("marker_id","id","name");


if($id and !$name) {
    $name=$id;
}
unless($marker_id and $marker_id=~/^\d+$/ and $marker_id>0) {
    if($name) {
        $page->message_page("This marker's page has moved.","<a href=\"/search/markers/markersearch.pl?w822_nametype=starts+with&w822_marker_name=$name&w822_submit=Search&w822_species=Any&w822_protos=Any&w822_colls=Any&w822_chromos=Any&w822_pos_start=&w822_pos_end=&w822_confs=-1&w822_maps=Any\">[Search new marker pages for $name]</a>");
    }
    else
    {
        $page->message_page('Marker ID is invalid',"Please try your <a href=\"/search/markers/markersearch.pl\">marker search</a> again.");
    }
}
my $marker=CXGN::Marker->new($dbh,$marker_id);
unless($marker) {
    my $current_id=CXGN::Marker::Tools::legacy_id_to_id($dbh,$marker_id);
    if($current_id) {
        $marker=CXGN::Marker->new($dbh,$current_id);
        unless($marker) {
            $page->error_page('Marker not found',"Please try your <a href=\"/search/markers/markersearch.pl\">marker search</a> again.",'exploded',"CXGN::Marker::Tools returned a current ID of '$current_id' for a legacy ID of '$marker_id', but a marker object could not be created from the current ID.");
        }
        $page->message_page("This marker's ID and detail page have changed.","It can now be viewed at the <a href=\"?marker_id=$current_id\">".$marker->name_that_marker()." (SGN-M$current_id) detail page</a>.");
    }
    $page->message_page('No marker exists with this ID',"Please try your <a href=\"/search/markers/markersearch.pl\">marker search</a> again.");
}
my @marker_names=$marker->name_that_marker();
my($marker_name,@other_names)=@marker_names;
my $display_name=$marker_name;
if(@other_names)
{
    $display_name.=" (also known as ".CXGN::Tools::Text::list_to_string(@other_names).")";
}
my $collections_string='';
my $collections_description='';
my $collections=$marker->collections();
if($collections and @{$collections})
{
    $collections_string=CXGN::Tools::Text::list_to_string(@{$collections})." ";
    for my $collection(@{$collections})
    {
        $collections_description.="$collection markers are ".CXGN::Marker::Tools::collection_name_to_description($dbh,$collection)."<br />";
    }
}

$page->header(
	      $collections_string."Marker $display_name (SGN-M$marker_id)",
	      $collections_string."Marker $display_name");
print"<div class=\"center\">SGN-M$marker_id<br />$collections_description";
print kfg_html($marker_id);
print "</div><br />\n";
print rflp_html($marker, $c );
print ssr_html($marker_id);
print cos_html($marker_id);
print cosii_orthologs_html($marker);
print derivations_html($marker);
print locations_html($marker, $display_name);
print polymorphisms_html($marker);
print unigene_match_html($marker_id);
print overgo_html($marker_id);
print cosii_polymorphisms_html($marker);
print cosii_files_html($marker, $c);
print attributions_html($marker_id);
print comments_html($marker);
print page_comment_html($marker_id);
$page->footer();



sub derivations_html {
    my $marker = shift;
    #sgn id, collections, and sources
    my $about_html='';
    my $sources=$marker->derived_from_sources();
    if($sources and @{$sources})
    {
        for my $source(@{$sources})
        {
            my $link='';
            if($source->{id_in_source})
            {
                if($source->{source_name} eq 'SGN unigene')
                {
                    $link="<a href=\"/search/unigene.pl?unigene_id=$source->{id_in_source}\">$source->{source_name} SGN-U$source->{id_in_source}</a>";
                }
                elsif($source->{source_name} eq 'EST read')
                {
                    $link="<a href=\"/search/est.pl?request_from=0&amp;request_id=SGN-E$source->{id_in_source}&amp;request_type=7&amp;search=search\">EST read SGN-E$source->{id_in_source}</a>";
                }
                elsif($source->{source_name} eq 'EST clone')
                {
                    $link="<a href=\"/search/est.pl?request_from=0&amp;request_id=SGN-C$source->{id_in_source}&amp;request_type=8&amp;search=search\">EST clone SGN-C$source->{id_in_source}</a>";
                }
                elsif($source->{source_name} eq 'BAC')
                {
                    my $clone=CXGN::Genomic::Clone->retrieve($source->{id_in_source});
                    my $bac_name=$clone->clone_name();
                    $link="<a href=\"/maps/physical/clone_info.pl?id=$source->{id_in_source} \">BAC $bac_name</a>";
                }
            }
            else
            {
                $link="a(n) $source->{source_name} (ID unknown)";
            }
            if($link)
            {
                $about_html.="This marker was derived from $link<br />";
            }
        }
    }
    if($about_html)
    {
        return blue_section_html('Derivations',$about_html);
    }
    else
    {
        return '';
    }
}



sub tm_html
{
    my $tm_html='';
    my $tm_query=
    '
        SELECT 
            s.tm_marker_seq_id, 
            s.tm_id, 
            s.sequence, 
	    s.comment, 
            tm.old_cos_id, 
            tm.marker_id, 
            ml.loc_id 
        FROM 
	    tm_markers as tm 
            LEFT JOIN tm_markers_sequences as s ON tm.tm_id=s.tm_id 
            LEFT JOIN markers as m ON tm.marker_id=m.marker_id 
            LEFT JOIN seqread AS q ON s.tm_marker_seq_id=q.read_id 
            LEFT JOIN marker_locations AS ml ON tm.marker_id=ml.marker_id 
        WHERE 
            tm.marker_id=?
    ';
    my $tm_sth=$dbh->prepare($tm_query);
    $tm_sth->execute($marker_id);
    my $r=$tm_sth->fetchrow_hashref();
    if($r)
    {
        $tm_html=<<END_HTML;
<b>Old COS ID:</b> $r->{old_cos_id}<br />
END_HTML
        $tm_html.="<b>Sequence:</b><br /><span class=\"sequence\">".CXGN::Page::FormattingHelpers::html_break_string($r->{sequence},80)."</span>";
    }
    if($tm_html)
    {
        return blue_section_html('TM info',$tm_html);
    }
    else
    {
        return '';
    }
}


sub kfg_html {
    
    my $marker_id = shift;
  # prints a link to the gene page if this marker maps to a gene 
  # (KFG = Known Function Gene)

  my $kfg_query = $dbh->prepare('SELECT locus_id, locus_name FROM phenome.locus_marker inner join phenome.locus using(locus_id) where marker_id=?');
  $kfg_query->execute($marker_id);
  
  return unless $kfg_query->rows() > 0;

  my $html = '';
  while (my ($locus_id, $locus_name) = $kfg_query->fetchrow_array()){

    $html .= qq{This marker is associated with the <a href="/phenome/locus_display.pl?locus_id=$locus_id">$locus_name</a> locus.<br />};
  }

  return $html.'<br />';

}


sub rflp_html {
    my $marker = shift;
    my $c = shift;
  my $ihtml = ""; 
  if ( SGN::Controller::Marker->rflp_image_link( $c, $marker ) )
  {
      $ihtml ="<br /><a href=\"/search/markers/view_rflp.pl?marker_id=$marker_id\">[$marker_name image]</a><br />";
  }
  my $rflp_query = q{SELECT r.rflp_id, r.marker_id, r.rflp_name, r.insert_size, 
	     r.vector, r.cutting_site, r.drug_resistance, 
	     fs.fasta_sequence as forward_seq, 
	     rs.fasta_sequence as reverse_seq, r.forward_seq_id, 
	     r.reverse_seq_id FROM 
	     rflp_markers AS r LEFT JOIN rflp_sequences AS fs ON 
	     r.forward_seq_id=fs.seq_id LEFT JOIN rflp_sequences AS rs 
	     ON r.reverse_seq_id=rs.seq_id WHERE marker_id=?};

  my $rflp_sth = $dbh->prepare($rflp_query); 
  $rflp_sth->execute($marker_id);
  my $r = $rflp_sth->fetchrow_hashref();
  unless($r->{rflp_id}){return'';}

  my $vhtml = <<EOT;
<b>Insert size: </b>$r->{insert_size}<br />
<b>Vector: </b>$r->{vector}<br />
<b>Cutting Site: </b>$r->{cutting_site}<br />
<b>Drug Resistance: </b>$r->{drug_resistance}<br />
EOT
  ;

  my $fs_html='<span class="ghosted">No forward sequence known.</span><br />';
  my $rs_html='<span class="ghosted">No reverse sequence known.</span><br />';
  if($r->{forward_seq})
  {
      $fs_html = '<br /><b>Forward sequence:</b><br /><span class="sequence">'.CXGN::Page::FormattingHelpers::html_break_string($r->{forward_seq},90).'</span><br />';
  }
  if($r->{reverse_seq})
  {
      $rs_html = '<br /><b>Reverse sequence:</b><br /><span class="sequence">'.CXGN::Page::FormattingHelpers::html_break_string($r->{reverse_seq},90).'</span><br /><br />';
  }


  #######################
  # unigene blast matches

  my $uhtml = '';

  my $unigene_page = '/search/unigene.pl?unigene_id=';
  my $rflp_name = $marker_name;
  my $e_val_blast_cutoff = '1.0e-4';


  my $sth = $dbh->prepare(q{SELECT unigene_id, e_val, 
				   align_length, query_start, 
				   query_end FROM rflp_unigene_associations 
				       WHERE rflp_seq_id=?});
  my %forward_unigene_matches;
  $sth->execute($r->{forward_seq_id});

  while (my ($ug_id, $e_val, $align_length, $q_start, $q_end) = $sth->fetchrow_array) {

    push @{$forward_unigene_matches{$e_val}}, qq|<tr><td><a href="$unigene_page$ug_id">SGN-U$ug_id</a></td><td align="center">$e_val</td><td align="center">$align_length</td></tr>\n|;
  }
  my %reverse_unigene_matches;
  $sth->execute($r->{reverse_seq_id});
  while (my ($ug_id, $e_val, $align_length, $q_start, $q_end) = $sth->fetchrow_array) {

    push @{$reverse_unigene_matches{$e_val}}, qq|<tr><td><a href="$unigene_page$ug_id">SGN-U$ug_id</a></td><td align="center">$e_val</td><td align="center">$align_length</td></tr>\n|;
  }
	    
  $uhtml .= "$rflp_name was matched against the Lycopersicon combined unigene build and produced the following matches:\n";
  $uhtml .= qq|<table border="0" width="100%" align="center">\n|;
  $uhtml .= qq|<tr>\n<td width="40%"><b>Forward sequence matches</b></td>\n<td width="30%" align="center"><b>e value</b></td>\n<td width="30%" align="center"><b>Alignment length (bp)</b></td>\n</tr>\n|;
  my @fwd_e_vals = keys %forward_unigene_matches;
  if (@fwd_e_vals) {
    foreach (sort {$a <=> $b} @fwd_e_vals) {
      $uhtml .= "" . join("\n", @{$forward_unigene_matches{$_}}) . "\n";
    }
  } else {
    $uhtml .= qq|<tr><td colspan="3" align="center">No matches with e-value below $e_val_blast_cutoff were found for this sequence.</td></tr>\n|;
  }
  $uhtml .= qq|<tr><td colspan="3"><br /></td></tr>\n|;
  $uhtml .= qq|<tr><td width="40%"><b>Reverse sequence matches</b></td>\n<td width="30%" align="center"><b>e value</b></td>\n<td width="30%" align="center"><b>Alignment length (bp)</b></td>\n</tr>\n|;
  my @rev_e_vals = keys %reverse_unigene_matches;
  if (@rev_e_vals) {
    foreach (sort {$a <=> $b} @rev_e_vals) {
      $uhtml .= "" . join("\n", @{$reverse_unigene_matches{$_}}) . "\n";
    }
  } else {
    $uhtml .= qq|<tr><td colspan="3" align="center">No matches with e-value below $e_val_blast_cutoff were found for this sequence.</td></tr>\n|;
  }

  $uhtml .= "</table>\n";

  my $html=$ihtml.$vhtml.$fs_html.$rs_html.$uhtml;
  if($html)
  {  
      return CXGN::Page::FormattingHelpers::blue_section_html('RFLP information',$html);  
  }
  else
  {
      return'';
  }

}



sub ssr_html  {
    my $marker_id = shift;

    my $html = "";
    my $query = 'SELECT repeat_motif, reapeat_nr FROM ssr_repeats WHERE marker_id='.$marker_id;
    my $repeats = $dbh->selectall_arrayref($query);
    my $contig_page='/search/unigene.pl?type=legacy&';
    my $est_page='/search/est.pl?request_type=automatic&amp;request_from=1&amp;request_id=';
    my $ssr_page='/search/markers/markerinfo.pl?marker_id=';
    my @ssr_list;
    my $ssr_sth = $dbh->prepare("SELECT s.ssr_id, s.marker_id, s.ssr_name, et.trace_name, s.start_primer, s.end_primer, s.pcr_product_ln, s.ann_high, s.ann_low FROM ssr AS s LEFT JOIN seqread AS et ON s.est_read_id=et.read_id where marker_id=?");
    my $repeats_sth = $dbh->prepare("SELECT repeat_motif, reapeat_nr FROM ssr_repeats WHERE ssr_id=?");
    $ssr_sth->execute($marker_id);
    if(my ($ssr_id, $marker_id, $ssr_name, $est_trace, $start_primer, $end_primer, $pcr_length, $ann_high, $ann_low) = $ssr_sth->fetchrow_array) 
    {
        $html.="<b>EST trace:</b> ".($est_trace ? "<a href=\"$est_page$est_trace\">$est_trace</a>" : "<span class=\"ghosted\">Unknown</span>"); 
        $ann_high ||= "n/a";
        $ann_low ||= "n/a";
        # Get the repeat motifs.
        my @repeat_motifs=();
        my @repeat_numbers=();
        $repeats_sth->execute($ssr_id);
        my $mapped = '';
        unless (defined($ssr_page)) {$ssr_page='';}
        unless (defined($marker_id)) {$marker_id='';}
        unless (defined($ssr_name)) {$ssr_name='';}
        unless (defined($est_trace)) {$est_trace='';}
        unless (defined($est_page)) {$est_page='';}
        unless (defined($ssr_id)) {$ssr_id='';}
        unless (defined($start_primer)) {$start_primer='';}
        unless (defined($end_primer)) {$end_primer='';}
        unless (defined($pcr_length)) {$pcr_length='';}
        unless (defined($ann_low)) {$ann_low='';}
        unless (defined($ann_high)) {$ann_high='';}
        unless (defined($mapped)) {$mapped='';}    
    	$html.="<br /><b>Annealing temperatures:</b> <b>Low:</b> " . $ann_low . " <b>High:</b> " . $ann_high;  
        while (my ($motif, $r_nr) = $repeats_sth->fetchrow_array) {
            $html.="<br /><b>Repeat motif:</b> <span class=\"sequence\">$motif</span>&nbsp;&nbsp;&nbsp;<b>Repeat number:</b> $r_nr";
        }
        $html.="<br /><b>Forward primer:</b> <span class=\"sequence\">$start_primer</span>";
        $html.="<br /><b>Reverse primer:</b> <span class=\"sequence\">$end_primer</span>";
        $html.="<br /><b>Predicted size:</b> $pcr_length";
    }
    if($html)
    {
        return CXGN::Page::FormattingHelpers::blue_section_html('SSR info',$html)
    }
    else
    {
        return'';
    }
}



sub cos_html {
    my $marker_id = shift;
  my $cos_query = q{SELECT c.cos_marker_id, c.marker_id, c.cos_id, c.at_match, 
	    c.at_position, c.bac_id, c.best_gb_prot_hit, c.at_evalue, 
	    c.at_identities, c.mips_cat, c.description, c.comment, 
	    c.gbprot_evalue, c.gbprot_identities, s.trace_name 
	    FROM cos_markers AS c LEFT JOIN seqread AS s ON 
	    c.est_read_id=s.read_id WHERE c.marker_id = ?};

  my $cos_sth = $dbh->prepare($cos_query);
  $cos_sth->execute($marker_id);
  my $r = $cos_sth->fetchrow_hashref();
  unless($r->{cos_marker_id}){return'';}
  my $at_page='http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&amp;db=Nucleotide&amp;dopt=GenBank&amp;list_uids=';
  my $map_link='/search/markers/markerinfo.pl?marker_id=';
  my $est_read_page='/search/est.pl?request_from=0&amp;request_type=automatic&amp;search=Search&amp;request_id=';
  my $cos_page='/search/markers/markerinfo.pl?marker_id=';
  my $at_match=$r->{at_match};
  my $bac_id=$r->{bac_id};
  my $trace_name=$r->{trace_name};
  my $at_posn=$r->{at_position};
  if($trace_name)
  {
    $trace_name="<a href=\"$est_read_page$trace_name\">$trace_name</a>"
  }
  else
  {
    $trace_name="<span class=\"ghosted\">None</span>";
  }
  my $vhtml = <<EOT;
<b><a href="/documents/markers/role_categories.txt">MIPS Category</a>: </b>$r->{mips_cat}<br />
<b>Tomato EST read:</b> $trace_name<br />
<b>Arabidopsis best BAC match:</b> <a href="$at_page$bac_id">$at_match</a><br />
<b>Arabidopsis position:</b> $at_posn<br />
EOT
  ;

  ###################
  # At orthology info

 my $at_page = 'http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=Nucleotide&dopt=GenBank&list_uids=';

  my $orth = <<EOT;
<b>Arabidopsis identities: </b>$r->{at_identities}<br />
EOT
  ;

  ##########################
  # GenBank protein hit info

  my $genbank = <<EOT;
<b>Best GenBank protein hit: </b><a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=Protein&amp;cmd=search&amp;term=$r->{best_gb_prot_hit}">$r->{best_gb_prot_hit}</a><br />
<b>Evalue: </b>$r->{gbprot_evalue}<br />
<b>Identities: </b>$r->{gbprot_identities}<br />
<b>Description: </b>$r->{description}<br />
<b>Comment: </b>$r->{comment}<br />
More information about COS markers can be found on the <a href="/markers/cos_markers.pl">COS markers</a> page.
EOT
  ;

  return CXGN::Page::FormattingHelpers::blue_section_html('COS information', $vhtml.$orth.$genbank);
#    . CXGN::Page::FormattingHelpers::blue_section_html('Arabidopsis orthology', $orth)
#      . CXGN::Page::FormattingHelpers::blue_section_html('Genbank protein hits', $genbank);

}



sub cosii_orthologs_html {
    my $marker = shift;
    unless($marker->is_in_collection('COSII')){return'';}
    use constant DESC_ALIGNED2AA=>'Alignment of DNA and translated peptides from Arabidopsis CDS and edited Asterid unigenes, plain text';
    use constant DESC_CDS_FASTA=>'Amplicon sequence alignment, FASTA';
    use constant DESC_CDS_NEX=>'Input file for PAUP, NEXUS format';
    use constant DESC_CDS_TXT=>'Original unigene seqs and Arabidopsis CDS seq, FASTA';
    use constant DESC_FR_CDS_FASTA=>'Alignment of Arabidopsis CDS and edited Asterid unigenes, FASTA';
    use constant DESC_ML_TRE=>'Phylogenetic tree';
    use constant DESC_PEP_ALN=>'Alignment of translated peptides from Arabidopsis CDS and edited Asterid unigenes, ClustalW';
    use constant DESC_PEP_FASTA=>'Alignment of translated peptides from Arabidopsis CDS and edited Asterid unigenes, FASTA';
    use constant DESC_AB1=>'AB1 chromatogram';
    use constant DESC_PDF=>'PDF chromatogram';
    use constant DESC_TXT=>'plain text';
    use constant DESC_BLASTX=>'BLASTX result of original unigene sequences against Arabidopsis protein database';
    use constant SEQUENCE_WIDTH=>90;
    use constant SEQUENCE_DATA_PRIVATE=>'Not available';
    use constant SEQUENCE_NAME_NOT_AVAILABLE=>'Name not available';
    use constant SEQUENCE_NOT_AVAILABLE=>'&nbsp;';
    use constant NO_UNIGENE_ID=>'Not available';
    use constant SINGLE_COPY=>'Single';
    use constant MULTIPLE_COPIES=>'Multiple';
    use constant NO_COPIES=>'No copies data found';
    my $cosii_data_files=cosii_data_files($marker,$c);
    my @unigenes=$marker->cosii_unigenes();
    my $html='';
    $html.="<br /><table border=\"1\" cellpadding=\"2\" cellspacing=\"0\" width=\"720\">";
    $html.="<tr><td>Species</td><td>Copies</td><td>Sequence ID</td><td>CDS/Edited sequence</td><td>Peptide sequence</td><td>Predicted introns</td></tr>";
    for(0..$#unigenes)
    {
        if($unigenes[$_]->{copies} eq 'S')
        {
            $unigenes[$_]->{copies}=SINGLE_COPY;
        }
        elsif($unigenes[$_]->{copies} eq 'M')
        {
            $unigenes[$_]->{copies}=MULTIPLE_COPIES;
        }
        else
        {
            $unigenes[$_]->{copies}=NO_COPIES;
        }
        if(!defined($unigenes[$_]->{sequence_name}) or $unigenes[$_]->{sequence_name} eq '')
        {
            $unigenes[$_]->{sequence_name}=CXGN::Marker::Tools::cosii_to_arab_name($marker_name);
        }
        if(!defined($unigenes[$_]->{organism}) or $unigenes[$_]->{organism} eq '')
        {
            $unigenes[$_]->{organism}=$unigenes[$_]->{database_name};
        }
        if(defined($unigenes[$_]->{unigene_id}))
        {
            if($unigenes[$_]->{organism}=~/Coffee/i)
            {
                my $new_sgn_id=CXGN::Unigene::Tools::cgn_id_to_sgn_id($dbh,$unigenes[$_]->{unigene_id});
                my $old_coffee_id=$unigenes[$_]->{unigene_id};
                $unigenes[$_]->{unigene_id}="<a href=\"/search/unigene.pl?unigene_id=$new_sgn_id\">$new_sgn_id (SGN)</a><br /><span class=\"ghosted\">$old_coffee_id (CGN)</span>";
            }
            else
            {
                $unigenes[$_]->{unigene_id}="<a href=\"/search/unigene.pl?unigene_id=$unigenes[$_]->{unigene_id}\">$unigenes[$_]->{unigene_id}</a>";
            }
        }
        else
        {
            $unigenes[$_]->{unigene_id}=NO_UNIGENE_ID;
        }
        my $organism_name_for_uri=URI::Escape::uri_escape($unigenes[$_]->{organism});
        my($ed_desc,$pep_desc,$int_desc)=('Edited','Peptide','Introns');
        $html.="<tr>";
        $html.="<td><b>$unigenes[$_]->{organism}</b></td>";
        $html.="<td>$unigenes[$_]->{copies}</td>";
        if($unigenes[$_]->{organism}=~/Arabidopsis/i)
        {
            $html.="<td>".CXGN::Marker::Tools::tair_gene_search_link($unigenes[$_]->{sequence_name})."</td>";
            $ed_desc='CDS from TAIR';
            $pep_desc='Peptide from TAIR'; 
            $int_desc='Introns from TAIR';
        }
        else
        {
            $html.="<td>$unigenes[$_]->{unigene_id}</td>";
        }
        $html.="<td>";
        if(${$cosii_data_files->{edited_seq_files}}[0])
        {
            for my $file(@{$cosii_data_files->{edited_seq_files}})
            {
                $html.="<a href=\"$file\">$ed_desc</a>";
            }
        }
        else{$html.=SEQUENCE_NOT_AVAILABLE;}
        $html.="</td><td>";
        if(${$cosii_data_files->{peptide_seq_files}}[0])
        {
            for my $file(@{$cosii_data_files->{peptide_seq_files}})
            {
                $html.="<a href=\"$file\">$pep_desc</a>";
            }
        }
        else{$html.=SEQUENCE_NOT_AVAILABLE;}
        $html.="</td><td>";
        if(${$cosii_data_files->{intron_seq_files}}[0])
        {
            for my $file(@{$cosii_data_files->{intron_seq_files}})
            {
                $html.="<a href=\"$file\">$int_desc</a>";
            }
        }
        else{$html.=SEQUENCE_NOT_AVAILABLE;}
        $html.="</td></tr>"; 
    }
    $html.='</table>';
    return blue_section_html('Orthologs in this COSII group',$html);
}



sub locations_html {
    my $marker = shift;
    my $display_name = shift;
    my $locations_html='';

    my @displayed_locs=();
    my @displayed_pcr=();
    #if we have some experiments, and they are an arrayref, and there is at least one location in them
    my $experiments=$marker->current_mapping_experiments();    
    if($experiments and @{$experiments} and grep {$_->{location}} @{$experiments}) {
        my $count = 1;
	for my $experiment(@{$experiments}) {

            #make sure we have a location before we go about showing location data--some experiments do not have locations
            if(my $loc=$experiment->{location}) {
                #make sure we haven't displayed a location entry with the same location ID already
                unless(grep {$_==$loc->location_id()} @displayed_locs) {
                    push(@displayed_locs,$loc->location_id());
                    if ($count > 1) {
			$locations_html .= '<br /><br /><br />';
		    }
		    $locations_html.='<table width="100%" cellspacing="0" cellpadding="0" border="0"><tr>';
                    #make a section detailing the location
                    my $protocol='';
                    my $pcr=$experiment->{pcr_experiment};
                    my $rflp=$experiment->{rflp_experiment};
                    $protocol=$experiment->{protocol};
                    unless($protocol) {
                        if($pcr) {
                            $protocol='PCR';
                        }
                        elsif($rflp) {
                            $protocol='RFLP';
                        }
                        else {
                            $protocol='<span class="ghosted">Unknown</span>';
                        }
                    }
    
                    #make a link to the map this marker can be found on
                    my $map_version_id=$loc->map_version_id();
                    my $lg_name=$loc->lg_name();
                    my $position=$loc->position();
                    my $subscript=$loc->subscript();
                    $subscript||='';
                    my $map_url='';
                    my $map_id='';
                    my $map_name='';
    
    		    if($map_version_id) {
                        my $map=CXGN::Map->new($dbh,{map_version_id=>$map_version_id});
                        $map_id=$map->map_id();
                        $map_name=$map->short_name();
                        if($map_id and $map_name and defined($lg_name) and defined($position)) {
                            $map_url="<a href=\"/cview/view_chromosome.pl?map_id=$map_id&amp;chr_nr=$lg_name&amp;cM=$position&amp;hilite=$marker_name$subscript&amp;zoom=1\">$map_name v$map_version_id</a>";
                        }
                    }
                    else {
                        $map_url='<span class="ghosted">Map data not available</span>';
                    }
                    my $multicol=1;
                    my $width="200px";
                    if($subscript and $multicol>1){$multicol++;}
    		    my @locations=
                    (
    		        '__title'   =>"<b>Map:</b> $map_url&nbsp;&nbsp;&nbsp;<span class=\"tinytype\">Loc. ID ".$loc->location_id()."</span>",
                        '__tableattrs'=>"width=\"$width\"",
                        '__multicol'=>$multicol,
                        'Chromosome'=>$loc->lg_name(),
                        'Position    '=>sprintf('%.2f cM',$loc->position()),
                        'Confidence'=>$loc->confidence(),
                        'Protocol'=>$protocol
                    );
                    if($subscript) {
                        push(@locations,('Subscript'=>$subscript));
                    }
                    $locations_html.='<td width = "25%">';
                    $locations_html.=CXGN::Page::FormattingHelpers::info_table_html(@locations);
                    $locations_html.='</td>';
                    $locations_html.='<td align="center">';
		    my $map_factory = CXGN::Cview::MapFactory->new($dbh);
		    my $map=$map_factory->create({map_version_id=>$map_version_id});
		    my $map_version_id=$map->get_id();
		    my $map_name=$map->get_short_name();
		    my $hilite_name = $display_name;
		    if ($subscript) {
			$hilite_name.=$subscript;
		    }
		    my $chromosome= CXGN::Cview::ChrMarkerImage->new("", 150,150,$dbh, $lg_name, $map, $hilite_name);
		    my ($image_path, $image_url)=$chromosome->get_image_filename();
		    my $chr_link= qq|<img src="$image_url" usemap="#map$count" border="0" alt="" />|;
		    $chr_link .= $chromosome->get_image_map("map$count");
		    $chr_link .= '<br />' . $map_name;
		    $count++;
		    $locations_html .= '<br />';
		    $locations_html .= $chr_link;
                    $locations_html.='</td></tr></table>';
            
                    #if we have a pcr experiment that was used to map this marker to this location, make a section for this experiment's data
                    if($pcr and !grep {$_==$pcr->pcr_experiment_id()} @displayed_pcr) {
                        $locations_html .= '<table width="100%" cellspacing="0" cellpadding="0" border="0"><tr>';
			my $pcr_bands=$pcr->pcr_bands_hash_of_strings();
                        my $digest_bands=$pcr->pcr_digest_bands_hash_of_strings();
                        my $pcr_bands_html = CXGN::Page::FormattingHelpers::info_table_html
			    ( __border => 0, __sub => 1,
			      map {
				  my $accession_name = CXGN::Accession->new($dbh,$_)->verbose_name;
				  $accession_name => $pcr_bands->{$_}
			      } keys %$pcr_bands,
			    );
                        my $digest_bands_html = CXGN::Page::FormattingHelpers::info_table_html
			    ( __border => 0, __sub => 1,
			      map {
				  my $accession_name=CXGN::Accession->new($dbh,$_)->verbose_name();
				  $accession_name => $digest_bands->{$_};
			      } keys %$digest_bands,
			    );
                        my $mg='';
                        if($pcr->mg_conc()) {    
                            $mg=$pcr->mg_conc().'mM';
                        }
                        my $temp='';
                        if($pcr->temp()) {    
                            $temp=$pcr->temp().'&deg;C';
                        }                    
                        $locations_html.='<td>';
                        my $fwd=$pcr->fwd_primer()||'<span class="ghosted">Unknown</span>';
                        my $rev=$pcr->rev_primer()||'<span class="ghosted">Unknown</span>';  
                        my $enz=$pcr->enzyme()||'unknown enzyme';                 
                        my $dcaps=$pcr->dcaps_primer();
                        $temp||='<span class="ghosted">Unknown</span>';
                        $mg||='<span class="ghosted">Unknown</span>';
                        my $digest_title="Digested band sizes (using $enz)";
                        unless($digest_bands_html) {
                            $digest_title='&nbsp;'; 
                            $digest_bands_html='&nbsp;'; 
                        }

                        ### TODO ###
			my ($dcaps_left,$dcaps_right);


			if ($dcaps) {
			    $dcaps_left = "dCAPS primer (5'-3')";
			    $dcaps_right = "<span class=\"sequence\">$dcaps</span>";
			}
			
                        $locations_html.=CXGN::Page::FormattingHelpers::info_table_html
                        (
                            '__title'=>"PCR data&nbsp;&nbsp;&nbsp;<span class=\"tinytype\">Exp. ID ".$pcr->pcr_experiment_id()."</span>",
                            "Forward primer (5'-3')"=>"<span class=\"sequence\">$fwd</span>",
                            "Reverse primer (5'-3')"=>"<span class=\"sequence\">$rev</span>",
			    $dcaps_left => $dcaps_right,
                            'Accessions and product sizes'=>$pcr_bands_html,
                            $digest_title=>$digest_bands_html,
                            'Approximate temperature'=>$temp,
                            'Mg<sup>+2</sup> concentration'=>$mg,
                            '__multicol'=>3,
                            '__tableattrs'=>"width=\"100%\"",
                        );
                        $locations_html.='</td></tr></table>';
                        push(@displayed_pcr,$pcr->pcr_experiment_id());
                    }
                }
            }
        }    	
    }

    return blue_section_html('Mapped locations',$locations_html);
}



sub polymorphisms_html {
    my $marker = shift;
    my $polymorphisms_html='';
    my @displayed_pcr=();
    my $experiments=$marker->experiments();    
    if($experiments and @{$experiments})
    {
        for my $experiment(@{$experiments})
        {
            my $pcr=$experiment->{pcr_experiment};
            my $rflp=$experiment->{rflp_experiment};
            if($pcr and !grep {$_==$pcr->pcr_experiment_id()} @displayed_pcr)
            {
                my $pcr_bands=$pcr->pcr_bands_hash_of_strings();
                my $digest_bands=$pcr->pcr_digest_bands_hash_of_strings();
                my $pcr_bands_html='';
                my $digest_bands_html='';
                for my $accession_id(keys(%{$pcr_bands}))
                {
                    my $accession_name=CXGN::Accession->new($dbh,$accession_id)->verbose_name();
                    $pcr_bands_html.="<b>$accession_name:</b> $pcr_bands->{$accession_id}<br />";
                }
                for my $accession_id(keys(%{$digest_bands}))
                {
                    my $accession_name=CXGN::Accession->new($dbh,$accession_id)->verbose_name();
                    $digest_bands_html.="<b>$accession_name:</b> $digest_bands->{$accession_id}<br />";
                }
                my $mg='';
                if($pcr->mg_conc())
                {    
                    $mg=$pcr->mg_conc().'mM';
                }
                my $temp='';
                if($pcr->temp())
                {    
                    $temp=$pcr->temp().'&deg;C';
                }                    
                $polymorphisms_html.='<tr><td width="100%">';
                my $fwd=$pcr->fwd_primer();
                my $rev=$pcr->rev_primer();
                if($fwd)
                {
                    $fwd='<span class="sequence">'.$fwd.'</span>';
                }
                else
                {
                    $fwd='<span class="ghosted">Unknown</span>';
                }
                if($rev)
                {
                    $rev='<span class="sequence">'.$rev.'</span>';
                }
                else
                {
                    $rev='<span class="ghosted">Unknown</span>';
                }  
                my $enz=$pcr->enzyme()||'unknown enzyme';                 
                $temp||='<span class="ghosted">Unknown</span>';
                $mg||='<span class="ghosted">Unknown</span>';
                my $digest_title="Digested band sizes (using $enz)";
                unless($digest_bands_html)
                {
                    $digest_title='&nbsp;'; 
                    $digest_bands_html='&nbsp;'; 
                }
                $polymorphisms_html.=CXGN::Page::FormattingHelpers::info_table_html
                (
                    '__title'=>"PCR data&nbsp;&nbsp;&nbsp;<span class=\"tinytype\">Exp. ID ".$pcr->pcr_experiment_id."</span>",
                    "Forward primer (5'-3')"=>"<span class=\"sequence\">$fwd</span>",
                    "Reverse primer (5'-3')"=>"<span class=\"sequence\">$rev</span>",
                    'Accessions and product sizes'=>$pcr_bands_html,
                    $digest_title=>$digest_bands_html,
                    'Approximate temperature'=>$temp,
                    'Mg<sup>+2</sup> concentration'=>$mg,
                    '__multicol'=>3,
                    '__tableattrs'=>"width=\"100%\"",
                );
                $polymorphisms_html.='</td></tr>';
            }
        }
    }
    if($polymorphisms_html)
    {
        return blue_section_html('Other PCR data','<table width="100%" cellspacing="0" cellpadding="0" border="0">'.$polymorphisms_html.'</table>');
    }
    else
    {
        return '';
    }
}



sub overgo_html {
    my $marker_id = shift;
	my $phys_html;

	#some page locations that may change
	my $bac_page = '/maps/physical/clone_info.pl?id=';
	my $overgo_plate_page = '/maps/physical/list_overgo_plate_probes.pl?plate_no=';
	my $plausible_definition_page = '/maps/physical/overgo_process_explained.pl#plausible';

	# New! Improved! Now uses SGN-managed $dbh rather than physical_tools

	#get the physical info, if any
	my ($overgo_version) = $dbh->selectrow_array("SELECT overgo_version FROM physical.overgo_version WHERE current=1;");
	my $physical_stm = q{  SELECT  pm.overgo_probe_id,               
                                        op.plate_number,
                                     	pm.overgo_plate_row,
					pm.overgo_plate_col,
					b.bac_id,
					b.cornell_clone_name,
					oap.plausible,
					pm.overgo_seq_A,
					pm.overgo_seq_B,
					pm.overgo_seq_AB,
					pm.marker_seq
				FROM physical.probe_markers AS pm
				LEFT JOIN physical.overgo_plates AS op
					ON pm.overgo_plate_id=op.plate_id
				LEFT JOIN physical.overgo_associations AS oa
					ON (pm.overgo_probe_id=oa.overgo_probe_id AND oa.overgo_version=?)
                                LEFT JOIN physical.oa_plausibility AS oap
                                        ON (oap.overgo_assoc_id=oa.overgo_assoc_id)
				LEFT JOIN physical.bacs AS b
					ON oa.bac_id=b.bac_id
				WHERE pm.marker_id=?
	                      };
	my $physical_sth = $dbh->prepare($physical_stm);
	$physical_sth->execute($overgo_version, $marker_id);

	#go over the results from the query above and load the results into memory,
	#getting rid of duplicates and suchlike chaff, avoiding duplicates mostly 
	#by storing things as keys in a hash instead of in a simple array

	my %overgos;  #hash by platelocation => a hash of sequence info
	my %plausible_BAC_matches;
	my %other_BAC_matches;
	while (my ($probeid, $platenum, $row, $col, $bacid, $bacname, $plausible, $seqA, $seqB, $seqAB, $markerseq) = $physical_sth->fetchrow_array) {

	  ### sock away the info on this overgo probe (location and sequences)

	  $overgos{$probeid}{loc} = {plate=>$platenum,coords=>$row.$col};

	  if($seqA || $seqB || $seqAB || $markerseq) {
	    $overgos{$probeid}{seqs} =
	      {seqA=>$seqA,seqB=>$seqB,seqAB=>$seqAB,markerseq=>$markerseq};
	  }

	  #if we have BACs associated with it, remember them
	  if ($bacid) {
	    my $baclink = qq|<a href="$bac_page$bacid">$bacname</a>|;
	    #store these as hash keys to prevent duplicates
	    if ($plausible) {
	      $overgos{$probeid}{plausible}{$baclink}=1;
	    } else {
	      $overgos{$probeid}{unplausible}{$baclink}=1;
	    }
	  }
	}

	#if we found some overgo stuff, output it
	if (%overgos) {
	  #go over the overgos we found and output info in HTML for each of them
	  my @overgoinfo; #array of html overgo info nuggets
	  while(my ($probeid,$thisprobe) = each %overgos) {
	    my $overgo_html;
	    $overgo_html .= qq|$marker_name was used as an overgo probe on <a href="$overgo_plate_page$thisprobe->{loc}{plate}&amp;highlightwell=$thisprobe->{loc}{coords}">plate $thisprobe->{loc}{plate}</a> [well $thisprobe->{loc}{coords}]<br />|;

	    #output the plausible BACs
	    $overgo_html .= qq{<p><b><a href="$plausible_definition_page">Plausible</a> BAC Matches:</b>&nbsp;&nbsp;&nbsp;}
	      .($thisprobe->{plausible} ? join(",&nbsp;&nbsp;\n", keys %{$thisprobe->{plausible}}) : 'None')
		."</p>\n";

	    #output the nonplausible BACs
	    if ($thisprobe->{unplausible}) {
	      $overgo_html .= html_optional_show("np$probeid",'<i>Non-Plausible</i> BAC matches',
					      join (",&nbsp;&nbsp;\n",
						    keys %{$thisprobe->{unplausible}})
					     );
	    }

	    #output the sequences for this overgo probe
	    my $seqhtml;
	    $seqhtml .= '<b>A Sequence</b><br />'
	      .html_break_string($thisprobe->{seqs}{seqA})
	      .'<br /><br />';

	    $seqhtml .= '<b>B Sequence</b><br />'
	      .html_break_string($thisprobe->{seqs}{seqB})
	      .'<br /><br />';

	    $seqhtml .= '<b>AB Sequence</b><br />'
	      .html_break_string($thisprobe->{seqs}{seqAB})
	      .'<br /><br />';

	    $seqhtml .= '<b>Marker Sequence</b><br />'
	      .html_break_string($thisprobe->{seqs}{markerseq})
	      .'<br />';

	    $overgo_html .= html_optional_show("seq$probeid",'<i>Overgo Sequences</i>',"<div>$seqhtml</div>");
	    push @overgoinfo, $overgo_html;
	  }

	  #now join together the over info units, putting <hr>s between them
	  $phys_html .= join "<hr />\n", @overgoinfo;

# 	  my @loclist = map  {my ($plateno,$row,$col) = split (/:/,$_); 
# 			       qq|<a href="$overgo_plate_page$plateno&highlightwell=$row$col">plate $plateno</a> [well $row$col]|;
# 			      } (keys %overgos);
	  #loclist is now a list of link strings made of the plate
	  #locations that were stored above as keys of %overgos

# 	  $phys_html .= "<p>$marker_name was used as a probe on ";
# 	  $phys_html .= list_to_string(@loclist);
# 	  $phys_html .= " of the Overgo Physical mapping process.</p>\n";


	} 

	# End of ugly code.
	#############################################
        if($phys_html) {
	    return blue_section_html('Overgo hybridization and physical mapping', $phys_html);
        }
        else {
            return '';
        }
}



sub cosii_polymorphisms_html {
    my $marker = shift;
    unless($marker->is_in_collection('COSII'))
    {
        return'';
    }
    my $html='<span class="ghosted">No additional PCR data found.</span>';

    #if we have some experiments, and they are an arrayref, and there is at least one location in them
    my $experiments=$marker->upa_experiments();
    if($experiments and @{$experiments})
    {

        #what we want here is just two or four primers: forward and reverse iUPA and/or forward and reverse eUPA primers for ALL of the experiments that will follow.
        #they all SHOULD share the same primers, so we only want to display them once, up on the top.
        #so here, we are going to walk through all of the experiments and grab the first forward and reverse iUPAs and eUPAs we see.
        #since this is not a bottleneck for speed in page loading, we are then going to continue on and do some data integrity checking as well with every page load.
        #we're going to check our assumption that all of these experiments will have the same primers.
        #we may later want to write a trigger in the database to check this instead.
        #we'll continue walking through all experiments and if any of them have non-matching primers, we'll notify the developers of this error.
        #whether the error turns out to be that our assumption was wrong, or that the data was wrong, will have to be determined by the developers.
        my $fwd_iupa='';
        my $rev_iupa='';
        my $fwd_eupa='';
        my $rev_eupa='';
        my $non_mapping_experiments=0;
        my $possible_error_email='';
        for my $marker_experiment(@{$experiments})
        {

            #keep track if we have any non mapping experiments to display, for use the next time we go through them
            unless($marker_experiment->{location})
            {
                $non_mapping_experiments++;
            }

            my $exp=$marker_experiment->{pcr_experiment};

            #if it is an iUPA experiment, set or check iUPA primers
            if($exp->primer_type() eq 'iUPA')
            {
                if($exp->fwd_primer())
                {
                    if($fwd_iupa)
                    {
                        if($fwd_iupa ne $exp->fwd_primer())
                        {
                            $possible_error_email.="Found unmatched fwd iUPA primers '$fwd_iupa' and '".$exp->fwd_primer()."' for '$marker_name'\n";
                        }
                    }
                    else
                    {
                        $fwd_iupa=$exp->fwd_primer();
                    }
                }            
                if($exp->rev_primer())
                {
                    if($rev_iupa)
                    {
                        if($rev_iupa ne $exp->rev_primer())
                        {
                            $possible_error_email.="Found unmatched rev iUPA primers '$rev_iupa' and '".$exp->rev_primer()."' for '$marker_name'\n";
                        }
                    }
                    else
                    {
                        $rev_iupa=$exp->rev_primer();
                    }
                }   
            }
            #else if it is an eUPA experiment, set or check eUPA primers
            elsif($exp->primer_type eq 'eUPA')
            {
                if($exp->fwd_primer())
                {
                    if($fwd_eupa)
                    {
                        if($fwd_eupa ne $exp->fwd_primer())
                        {
                            $possible_error_email.="Found unmatched fwd eUPA primers '$fwd_eupa' and '".$exp->fwd_primer()."' for '$marker_name'\n";
                        }
                    }
                    else
                    {
                        $fwd_eupa=$exp->fwd_primer();
                    }
                }            
                if($exp->rev_primer())
                {
                    if($rev_eupa)
                    {
                        if($rev_eupa ne $exp->rev_primer())
                        {
                            $possible_error_email.="Found unmatched rev eUPA primers '$rev_eupa' and '".$exp->rev_primer()."' for '$marker_name'\n";
                        }
                    }
                    else
                    {
                        $rev_eupa=$exp->rev_primer();
                    }
                }                 
            }
            #else we got data we don't know how to display yet
            else
            {
                CXGN::Apache::Error::notify('found a primer which could not be displayed',"Experiments of type '".$exp->primer_type()."' cannot yet be displayed.");
            }
        }
        if($possible_error_email)
        {
            CXGN::Apache::Error::notify('found unmatched primers for $marker_name',$possible_error_email);    
        }

        #now we're done looking for primers. 
        #if we found any non-mapping experiments above, then it's time to display them.
        if($non_mapping_experiments)
        {
            my %display_hash;
            for my $marker_experiment(@{$experiments})
            {

                #experiments without locations are the ones we want to display here
                unless($marker_experiment->{location})
                {
                    my $exp=$marker_experiment->{pcr_experiment};
                    my $bands_hash=$exp->pcr_bands_hash_of_strings();
                    my($accession_id)=keys(%{$bands_hash});
                    my $accession=CXGN::Accession->new($dbh,$accession_id);
                    my $key_string="<b>".$accession->organism_common_name()."</b> ".$accession->verbose_name();
                    if($exp->primer_type() eq 'iUPA')
                    {
                        $display_hash{$key_string}->{iUPA}->{bands}=$bands_hash->{$accession_id};
                        $display_hash{$key_string}->{iUPA}->{temp}=$exp->temp();
                        $display_hash{$key_string}->{iUPA}->{mg_conc}=$exp->mg_conc();
                    }
                    elsif($exp->primer_type() eq 'eUPA')
                    {
                        $display_hash{$key_string}->{eUPA}->{bands}=$bands_hash->{$accession_id};
                        $display_hash{$key_string}->{eUPA}->{temp}=$exp->temp();
                        $display_hash{$key_string}->{eUPA}->{mg_conc}=$exp->mg_conc();
                    }
                }
            }
            $html="<table border=\"1\" cellpadding=\"2\" cellspacing=\"0\" width=\"720\">";
            $html.="<tr>";
            $html.="<td><b>Testing intronic and exonic universal primers for Asterid species</b></td>";
            $html.="<td colspan=\"3\">";
            if($fwd_iupa)
            {
                $html.="<b>Forward <a href=\"/markers/cosii_markers.pl\">Intronic UPA</a> (5'-3'):</b> <span class=\"sequence\">$fwd_iupa</span><br />";
            }
            else
            {
                $html.="&nbsp;<br /><br />";
            }
            if($rev_iupa)
            {
                $html.="<b>Reverse <a href=\"/markers/cosii_markers.pl\">Intronic UPA</a> (5'-3'):</b> <span class=\"sequence\">$rev_iupa</span><br />";
            }
            else
            {
                $html.="&nbsp;<br /><br />";
            }
            $html.="</td>";
            $html.="<td colspan=\"3\">";
            if($fwd_eupa)
            {
                $html.="<b>Forward <a href=\"/markers/cosii_markers.pl\">Exonic UPA</a> (5'-3'):</b> <span class=\"sequence\">$fwd_eupa</span><br />";
            }
            else
            {
                $html.="&nbsp;<br /><br />";
            }
            if($rev_eupa)
            {
                $html.="<b>Reverse <a href=\"/markers/cosii_markers.pl\">Exonic UPA</a> (5'-3'):</b> <span class=\"sequence\">$rev_eupa</span><br />";
            }
            else
            {
                $html.="&nbsp;<br /><br />";
            }
            $html.="</td>";
            $html.="</tr>";
            $html.="<tr><td><b>Accession</b></td><td><b>PCR size(s)</b></td><td><b>Anneal temp.</b></td><td><b>Mg<sup>+2</sup> conc. (mM)</b></td><td><b>PCR size(s)</b></td><td><b>Anneal temp.</b></td><td><b>Mg<sup>+2</sup> conc. (mM)</b></td></tr>";
            for my $accession_name(sort {$a cmp $b} keys(%display_hash))
            {
                $display_hash{$accession_name}->{iUPA}->{bands}||='&nbsp;';
                $display_hash{$accession_name}->{iUPA}->{temp}||='&nbsp;';
                $display_hash{$accession_name}->{iUPA}->{mg_conc}||='&nbsp;';
                $display_hash{$accession_name}->{eUPA}->{bands}||='&nbsp;';
                $display_hash{$accession_name}->{eUPA}->{temp}||='&nbsp;';
                $display_hash{$accession_name}->{eUPA}->{mg_conc}||='&nbsp;';
                $html.="<tr>";
                $html.="<td>$accession_name</td>";
                $html.="<td>$display_hash{$accession_name}->{iUPA}->{bands}</td>";
                $html.="<td>$display_hash{$accession_name}->{iUPA}->{temp}</td>";
                $html.="<td>$display_hash{$accession_name}->{iUPA}->{mg_conc}</td>";
                $html.="<td>$display_hash{$accession_name}->{eUPA}->{bands}</td>";
                $html.="<td>$display_hash{$accession_name}->{eUPA}->{temp}</td>";
                $html.="<td>$display_hash{$accession_name}->{eUPA}->{mg_conc}</td>";
                $html.="</tr>";
            }
            $html.="</table>";
        }
    }
    return blue_section_html('Universal primers for Asterid species',$html);
}



sub cosii_files_html {
    my $marker = shift;
    my $c = shift;
    unless($marker->is_in_collection('COSII')){return'';}
    my($html,$html1,$html2,$html3,$html4,$html5,$html6)=('','','','','','');
    my $header = "<hr />";
    my $cosii_files=cosii_data_files( $marker, $c->config )->{all_other_data_files};

    for my $additional_data_file(sort {$a cmp $b} @{$cosii_files})
    {



        my $description='';
        my $real_location=$additional_data_file;
        my $data_shared_website_path=$c->config->{'static_datasets_path'};
        $real_location=~s/$data_shared_website_path//;
        $real_location=URI::Escape::uri_escape($real_location);
        my $display_name=$additional_data_file;
        my $view_link='';
        if($additional_data_file=~/([^\/]+)$/){$display_name=$1;}
        if($display_name=~/\.blastx$/)
        {
            $description=DESC_BLASTX;
            $html1.="<a href=\"$additional_data_file\">$description</a><br />";
        }
        elsif($display_name=~/[^FRfr]+\.cds\.fasta$/)
        {
            $description=DESC_FR_CDS_FASTA;
            $html2.="<a href=\"$additional_data_file\">$description</a><br />";
        }
        elsif($display_name=~/\.aligned2aa$/)
        {
            $description=DESC_ALIGNED2AA;
            $html2.="<a href=\"$additional_data_file\">$description</a><br />";
        }
        elsif($display_name=~/\.pep\.aln$/)
        {
            $description=DESC_PEP_ALN;
            $html2.="<a href=\"$additional_data_file\">$description</a><br />";
        }
        elsif($display_name=~/\.pep\.fasta$/)
        {
            $description=DESC_PEP_FASTA;
            $html2.="<a href=\"$additional_data_file\">$description</a><br />";
        }
        elsif($display_name=~/\.cds\.nex$/)
        {
            $description=DESC_CDS_NEX;
            $html3.="<a href=\"$additional_data_file\">$description</a><br />";
        } 
        elsif($display_name=~/\.ml\.tre$/)
        {
            $description=DESC_ML_TRE;
            $html3.="<a href=\"$additional_data_file\">$description</a><br />";
            my $file_url=URI::Escape::uri_escape($additional_data_file);
            $html3.="<a href=\"$additional_data_file\">$description</a>&nbsp;&nbsp;&nbsp;|&nbsp;&nbsp;&nbsp;<a href=\"/tools/tree_browser/?shared_file=$file_url\">[View]</a><br />"; 
        }
        elsif($display_name=~/\.cds\.fasta$/)
        {
            $description=DESC_CDS_FASTA;
            $html4.="<a href=\"$additional_data_file\">$description</a><br />";
        }
        elsif($display_name=~/\.txt$/ or $display_name=~/\.seq$/)
        {
            $description=&_cosii_additional_description($display_name).", ".DESC_TXT;
            $html4.="<a href=\"$additional_data_file\">$description</a><br />";
        }
        elsif($display_name=~/\.pdf$/)
        {
            $description=&_cosii_additional_description($display_name).", ".DESC_PDF;
            $html4.="<a href=\"$additional_data_file\">$description</a><br />";
        }
        elsif($display_name=~/\.ab1$/)
        {
            $description=&_cosii_additional_description($display_name).", ".DESC_AB1;
            $view_link=" - <a href=\"/tools/trace_view.pl?file=$real_location\">[View]</a>";
            $html4.="<a href=\"$additional_data_file\">$description</a> $view_link<br />";
        }
        elsif($display_name=~/\.cds\.txt$/)
        {
            $description=DESC_CDS_TXT;
            #display nothing
        }
        else
        {
            $description=$display_name;
            $html6.="<a href=\"$additional_data_file\">$description</a><br />";
        }
    }

    my $html7 = &cosii_files_html_2;

    if($html1){$html.=$header.$html1;}
    if($html2){$html.=$header.$html2;}
    if($html3){$html.=$header.$html3;}
    if($html4){$html.=$header.$html4;}
    if($html5){$html.=$header.$html5;}
    if($html6){$html.=$header.$html6;}
    if($html7){$html.=$html7;}
    if($html){$html.=$header;}
    if($html)
    {
        return CXGN::Page::FormattingHelpers::blue_section_html('Other COSII sequence data',$html);
    }
    else{return'';}
}


sub cosii_files_html_2
{
    my $marker = $marker_name;
    $marker =~ s/C2_At//;
    my $html;

    my $table = "forward_amplicon_sequence_markers";

    my $select = "select ending from $table where marker_name = '$marker' order by ending;";

    my $sth = $dbh->prepare("$select");
    $sth->execute;
    
    while (my $ending = $sth->fetchrow()) {
	$html .= &get_information($marker,$ending);
    }

    $sth->finish;

    return $html;
}

sub get_information {
    my ($marker,$ending) = @_;

    my $vhost_conf = CXGN::VHost->new();
    my $cosii_file = $vhost_conf->get_conf('cosii_files');

    my $table = "forward_amplicon_sequence_information";
    my $html;

    my ($number, $dashnumber, $parennumber) = "";
    if ($ending =~ /(\w+)-(\d+)/) {
	$ending = $1;
	$number = $2;
	$dashnumber = "-$number";
	$parennumber = " ($number)";
    }
    my $select = "select organism_name, accession_id, plant_number "
	. "from $table where ending = '$ending';";
    my $sth = $dbh->prepare("$select");
    $sth->execute;
    my ($organism, $accession, $plant) = $sth->fetchrow();
    
    ($plant eq '0') ? ($plant="") : ($plant = " plant #$plant");
	($accession eq '0') ? ($accession="") : ($accession=" $accession");
    
    my $ab1 = "$cosii_file/ab1/$marker-$ending$dashnumber.ab1";
    my $seq = "$cosii_file/seq/$marker-$ending$dashnumber.seq";
    my $text = "Forward amplicon sequence for $organism$accession$plant$parennumber,";

    $html .= "<a href=\"$ab1\">$text AB1 chromatogram</a> - "
	. "<a href=\"/tools/trace_view.pl?file=$ab1\">[View]</a><br />"
	. "<a href=\"$seq\">$text plain text</a><br />";
    $sth->finish;
    
    return $html;
}




sub unigene_match_html {
    my $marker_id = shift;
  my $html='';

  my $unigene_matches = $dbh->selectcol_arrayref("SELECT DISTINCT unigene_id FROM primer_unigene_match WHERE marker_id=$marker_id");

  foreach my $ug (@$unigene_matches){

    $html .= qq{<a href="/search/unigene.pl?unigene_id=SGN-U$ug">SGN-U$ug</a><br>};

  }
  
  if ($html){
    $html = CXGN::Page::FormattingHelpers::blue_section_html('Unigene blast matches for primers',$html);
  } 

  return $html;

}



sub attributions_html {
    my $marker_id = shift;

    my $att = CXGN::Metadata::Attribution->new("sgn","markers",$marker_id);

    my $db_name = 'sgn';
    my $table_name = 'markers';
    my $row_id = $marker_id;

    my @a = $att -> get_attributions();

    my $html = "";
    foreach my $a (@a) { 
	if ($a->{role}) { $html .= "<h4>$a->{role}</h4>"; }
	if ($a->{person}->get_last_name()) { $html .= "<b>Name:</b> ".$a->{person}->get_first_name()." ".$a->{person}->get_last_name()."<br />"; }
	if ($a->{organization}) { $html .= "<b>Organization:</b> ".$a->{organization}." <br />"; }
	if ($a->{project}) { $html .= "<b>Project:</b> ".$a->{project}." <br /><br />"; }
    }

    if($html)
    {
        return CXGN::Page::FormattingHelpers::blue_section_html("Attributions", $html);
    }
    else
    {
        return'';
    }
}



sub comments_html {
    my $marker = shift;

    my $comments=$marker->comments();
    if($comments)
    {
        return blue_section_html('Comments',newlines_to_brs($comments));
    }
    else
    {
        return'';
    }
}



sub page_comment_html {
#    return CXGN::People::PageComment->new("marker",$marker_id)->get_html();
#  return qq{<span class="noshow" id="commentstype">marker</span>
#<span class="noshow" id="commentsid">$marker_id</span>
#<div id="commentsarea" style="padding: 1em; color: #666; border: thin solid #666;">I wonder if there are any comments</div>};

    my $marker_id = shift;
    
    my $referer = $page->{request}->uri()."?".$page->{request}->args();
    return $page->comments_html('marker', $marker_id, $referer);

}



#this function comes up with a description of a cosii file's contents, 
#based on the name of the file. obviously, file nameing conventions
#MUST be maintained.
sub _cosii_additional_description
{
    my($display_name)=@_;
    my $additional_description='';
    if($display_name=~/([FRfr])(\d+)[\-\.]/)
    {
        my $direction=$1;
        my $accession_abbr=$2;

        if($direction=~/[fF]/){$additional_description='Forward';}
        if($direction=~/[rR]/){$additional_description='Reverse';}
        if($accession_abbr)
        {
            my @accession_ids=CXGN::Accession::Tools::partial_name_to_ids($dbh,$accession_abbr);
            if(@accession_ids==1)
            {
                my $accession_object=CXGN::Accession->new($dbh,$accession_ids[0]);
                $additional_description.=' amplicon sequence for '.$accession_object->verbose_name();
            }
            else
            {
                $additional_description.=" sequence for $accession_abbr";
            }
        }
    }
    else
    {
        $additional_description=$display_name;
    }
    return $additional_description;
}

sub cosii_data_files {
    my ($marker, $conf) = @_;

    unless($marker->is_in_collection('COSII')){return;}
    my $cosii_data_files={};
    my $seq_file_search_string=CXGN::Marker::Tools::cosii_name_to_seq_file_search_string($marker->name_that_marker());
    my $data_shared_website_path=$conf->{'static_datasets_path'};
    my $additional_data_files_string=`find $data_shared_website_path/cosii -type f -iregex ".*$seq_file_search_string.*"`;
    my @files=split("\n",$additional_data_files_string);
    my @edited_seq_files;
    my @peptide_seq_files;
    my @intron_seq_files;
    my @all_other_data_files;
    for my $file(@files)
    {
        my $data_shared_url=$conf->{'static_datasets_url'};
        $file=~s/$data_shared_website_path/$data_shared_url/;
        if($file=~/\.cds\.txt\.modify$/)
        {
            push(@edited_seq_files,$file);
        }
        elsif($file=~/\.pep\.txt$/)
        {
            push(@peptide_seq_files,$file);
        }
        elsif($file=~/\.intron.txt$/)
        {
            push(@intron_seq_files,$file);
        }
        else
        {
            push(@all_other_data_files,$file);
        }
    }
    $cosii_data_files->{edited_seq_files}=\@edited_seq_files;
    $cosii_data_files->{peptide_seq_files}=\@peptide_seq_files;
    $cosii_data_files->{intron_seq_files}=\@intron_seq_files;
    $cosii_data_files->{all_other_data_files}=\@all_other_data_files;
    $cosii_data_files->{all_files}=\@files;
    return $cosii_data_files;
}


1;
