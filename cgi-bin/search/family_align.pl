#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;
use CXGN::DB::Connection;
use CXGN::Alignment;
use File::Temp;
use Bio::Seq;
use Bio::SeqIO;

our $page = CXGN::Page->new( "SGN Gene Family Alignment", "Chenwei Lin");

my $family_size_limit = 100;

my ($family_id) = $page->get_arguments("family_id");
if ($family_id eq ""){
  empty_search($page);
}

##Connect to database and define queries

my $dbh = CXGN::DB::Connection->new();

my $at_family_member_q = $dbh->prepare("select sequence_name from family_member where family_id = ? and database_name like 'Arabidopsis'");

my $sgn_family_member_q = $dbh->prepare("select unigene_id, family_member.cds_id, organism_group_id from family_member left join cds using (cds_id) where family_id = ? and (database_name like'SGN' or database_name like 'CGN')");

my $organism_group_q = $dbh->prepare("select comment from groups where group_id = ?");

my $sgn_align_seq_q = $dbh->prepare("select alignment_seq from family_member left join cds using (cds_id) where unigene_id = ? and family_id = ?");

my $at_align_seq_q = $dbh->prepare("select alignment_seq from family_member where sequence_name like ? and database_name like 'Arabidopsis' and family_id = ?");

my $family_tree_log_q = $dbh->prepare("select tree_taxa_number, tree_overlap_length, tree_log_file_location from family where family_id = ? and tree_taxa_number > 3");

my $family_tree_nw_q = $dbh->prepare("select tree_nr, newick_unigene from family_tree where family_id = ?");

##Variables for each display sections.   There are five sections: align_image, summary, splice variants, sequence_analyisis, sequence_output.
my ($sum_content, $align_content, $sv_content, $al_content, $seq_sum_content, $seq_output_content, $gene_tree_content);



####################################################
#Get family member information.

my @at_member = ();
my %sgn_member = ();
my @all_sgn_member = ();
my %group_comment = ();

##Retrieve Arabidoposis family members

$at_family_member_q->execute($family_id);
while( my ($member) = $at_family_member_q->fetchrow_array()){
  my $locus = substr ($member, 0,9);
  push @at_member, $member;
}

##Retrieve SGN family members, group them by organisms

$sgn_family_member_q->execute($family_id);
while( my ($member, $cds_id, $organism_group_id) = $sgn_family_member_q->fetchrow_array()){
  push @{$sgn_member{$organism_group_id}}, $member;
  push @all_sgn_member, $cds_id;
}

foreach (keys %sgn_member){
  $organism_group_q->execute($_);
  if (my ($comment) = $organism_group_q->fetchrow_array()){
    $group_comment{$_} = $comment;
  }
}

######################################################
#Retrieve alignment sequences and store them in a align object $family_align
my $family_align;

##First check family size
my $total_member_nr = int (@all_sgn_member) + int (@at_member);
($total_member_nr <2 ) and &not_applicable($page, $family_id, $total_member_nr);
($total_member_nr >= $family_size_limit) and large_size($page, $family_id, $total_member_nr);


##Retrieve alignment sequences, SGN and Arabidopsis seperately
my %align_seq = ();
foreach (keys %sgn_member) {
  my $organism = $_;
  foreach (@{$sgn_member{$organism}}) {
    my $unigene_id = $_;
    $sgn_align_seq_q->execute($unigene_id, $family_id);
    if (my ($alignment_seq) = $sgn_align_seq_q->fetchrow_array()){
      chomp $alignment_seq;
      $align_seq{$unigene_id} = $alignment_seq;
    }
  }
}

foreach (@at_member) {
  $at_align_seq_q->execute($_, $family_id);
  if (my ($alignment_seq) = $at_align_seq_q->fetchrow_array()){
    chomp $alignment_seq;
    $align_seq{$_} = $alignment_seq;
  }
}
#use Data::Dumper;
#warn Dumper \%align_seq;#for debug purpose

#############################
#Create a family_align object and save the data in it

$family_align = CXGN::Alignment::align->new(align_name=>$family_id, 
					    width=>800, 
					    height=>2000, 
					    type=>'nt'
					   );

my ($my_align_seq, $len);

#Adding align_seqs members this way, instead of by going through keys of %align_seq, so that the align_seqs members are grouped by their species  
foreach (keys %sgn_member) {
  my $organism = $_;
  foreach (@{$sgn_member{$organism}}) {
    my $organism_name = $group_comment{$organism};
    if (defined $align_seq{$_}) {
      $len = length ($align_seq{$_});
      $my_align_seq = CXGN::Alignment::align_seq->new(horizontal_offset=>0,
						      vertical_offset=>0, 
						      length=>400,
						      height=>15, 
						      start_value=>1, 
						      end_value=>$len, 
						      id=>$_, 
						      seq=>$align_seq{$_}, 
						      species=>$organism_name
						     );
      $my_align_seq->set_url("unigene.pl?unigene_id=$_");

      $family_align->add_align_seq($my_align_seq);
    }
  }
}

foreach (@at_member) {
  if (defined $align_seq{$_}) {
    $len = length $align_seq{$_};
    my $my_align_seq = CXGN::Alignment::align_seq->new(horizontal_offset=>0,
						      vertical_offset=>0, 
						      length=>400,
						      height=>15, 
						      start_value=>1, 
						      end_value=>$len, 
						      id=>$_, 
						      seq=>$align_seq{$_}, 
						      species=>'Arabidopsis'
						     );
    my $locus = substr ($_, 0,9);
    $my_align_seq->set_url("http://www.arabidopsis.org/servlets/TairObject?type=locus&amp;name=$locus");
 
    $family_align -> add_align_seq($my_align_seq);
  }
}


#########################################################
#Retrieve selected range, overlap length, no hidden member and so on
#Store the numbers in $sum_content

my $range_start = $family_align -> get_start_value();
my $range_end = $family_align -> get_end_value();

my $overlap_len = $family_align -> get_overlap_num();

#this number might be different from $total_member_nr, since some sequences failed when being converted from peptide to nucleotide and were left out
my @all_align_members = $family_align -> get_nonhidden_member_ids();
my $total_align_member = int (@all_align_members);

#This number might be different from $total_align_member since some mebers might be hidden
my @nonhidden_align_members = $family_align->get_nonhidden_member_ids();
my $total_show_align_member = int (@nonhidden_align_members);

$sum_content = "<tr><td colspan=\"2\"><a target=\"blank\" href=\"/about/fam_align_analysis.pl\">For help with how we made the alignment, please click here.</a></td></tr>";
$sum_content .="<tr><th>Sequence Type</th><td>Nucleotide</td></tr>";
$sum_content .= "<tr><th>Total Family Members</th><td>$total_member_nr</td></tr>";
$sum_content .= "<tr><th>Available Member Sequences</th><td>$total_align_member</td></tr>";
$sum_content .= "<tr><th>Show Member Sequences</th><td>$total_show_align_member</td></tr>";
$sum_content .= "<tr><th>Range</th><td>$range_start - $range_end bp</td></tr>";
$sum_content .= "<tr><th>Overlap</th><td>$overlap_len bp</td></tr>";

$sum_content .= "<tr><td colspan=\"2\" align=\"center\"><a target=\"blank\" href=\"/about/align_term.pl\">For an explanation of the terms, plase click here.</a></td></tr>";

#############################################################
#Draw family_alignment image

#Generate temp file handles
my $vhost_conf = CXGN::VHost->new();
my $html_root_path = $vhost_conf->get_conf('basepath');
my $doc_path = $vhost_conf->get_conf('tempfiles_subdir').'/align_viewer';
my $path = $html_root_path . $doc_path;

my $tmp_image = new File::Temp(
			       DIR => $path,
			       SUFFIX => '.png',
			       UNLINK => 0,
			      );

##Render image
$family_align -> render_png_file($tmp_image, 'c');
close $tmp_image;
$tmp_image =~ s/$html_root_path//;

$align_content = "<tr><td><center><img src=\"$tmp_image\" usemap=\"#align_image_map\" alt=\"\" /></center></td></tr>";
$align_content .= "<tr><td>To view details for a particular family member, click the member image or the identifier.</td></tr>";

###Write image map
my $map_string = $family_align->write_image_map();
$align_content .= "<tr><td>$map_string</td></tr>";

######################################################
#Find putative splice variants
my ($ob_ref, $pi_ref, $sp_ref) = $family_align -> get_sv_candidates();
my %ob = %$ob_ref;
my %pi = %$pi_ref;
my %species = %$sp_ref;
$sv_content = "<tr><th>Species</th><th>Sequence id</th><th>Sequence id</th><th>Overlap Bases</th><th>%Identical</th></tr>";
foreach my $first_key (keys %ob) {
  foreach my $second_key (keys %{$ob{$first_key}}) {
    $sv_content .= "<tr><td>$species{$first_key}</td><td>$first_key</td><td>$second_key</td><td>$ob{$first_key}{$second_key}</td><td>$pi{$first_key}{$second_key}</td></tr>";
  }
}


######################################################
#Find putative allele pairs
my ($al_ob_ref, $al_pi_ref, $al_sp_ref) = $family_align -> get_allele_candidates();
my %al_ob = %$al_ob_ref;
my %al_pi = %$al_pi_ref;
my %al_species = %$al_sp_ref;
$al_content = "<tr><th>Species</th><th>Sequence id</th><th>Sequence id</th><th>Overlap Bases</th><th>%Identical</th></tr>";
foreach my $first_key (keys %al_ob) {
  foreach my $second_key (keys %{$al_ob{$first_key}}) {
    $al_content .= "<tr><td>$al_species{$first_key}</td><td>$first_key</td><td>$second_key</td><td>$al_ob{$first_key}{$second_key}</td><td>$al_pi{$first_key}{$second_key}</td></tr>";
  }
}


######################################################
#Analyze sequences
my $family_member_ids_ref = $family_align->get_member_ids();
my $ov_score_ref = $family_align -> get_all_overlap_score();
my $medium_ref = $family_align -> get_all_medium();
my ($head_ref, $tail_ref) = $family_align -> get_all_range();
my $ng_ref = $family_align -> get_all_nogap_length();
my $sp_ref = $family_align->get_member_species();
my $url_ref = $family_align->get_member_urls();

my @family_member_ids = @$family_member_ids_ref;
my %species = %$sp_ref;
my %ov_score = %$ov_score_ref;
my %medium = %$medium_ref;
my %head = %$head_ref;
my %tail = %$tail_ref;
my %ng = %$ng_ref;
my %gap = ();
my %url = %$url_ref;

foreach (keys %ng) {
  $gap{$_} = $tail{$_} - $head{$_} + 1 - $ng{$_};
}


$seq_sum_content = "<tr><th>Sequence id</th><th>Species</th><th>Cover Range</th><th>Bases</th><th>Gaps</th><th>Medium</th><th>Overlap Score</th></tr>";

foreach (@family_member_ids) { ##Access the align_seqs members this way, instead of by the keys of the hashes,  so that the sequences are grouped together
  $seq_sum_content .= "<tr><td><a target=\"blank\" href=\"$url{$)}\">$_</a></td><td>$species{$_}</td><td>$head{$_} - $tail{$_}</td><td>$ng{$_}</td><td>$gap{$_}</td><td>$medium{$_}</td><td>$ov_score{$_}</td></tr>";
}

#####################################################
#Write sequence output content

my $seq_ref = $family_align->get_nopad_seqs();
my $align_seq_ref = $family_align -> get_seqs();
my $ol_seq_ref = $family_align -> get_overlap_seqs();

if (defined $seq_ref) {

  my $tmp_seq_file = new File::Temp(
				    DIR => $path,
				    SUFFIX => '.txt',
				    UNLINK => 0,
				   );

  my %seqs = %$seq_ref;
  
  my $seq_io_obj = Bio::SeqIO->new('-fh' => $tmp_seq_file,
				   '-format' => 'fasta'
				  );
  foreach (@family_member_ids) {
    my $comp_id = $_ . '-' . $species{$_};
    $comp_id =~ s/\s/_/g;
    my $seq_obj = Bio::Seq->new('-seq' => $seqs{$_},
				'-id' => $comp_id
			       );
    $seq_io_obj->write_seq($seq_obj);
  }
  close $tmp_seq_file;

  $tmp_seq_file =~ s/$html_root_path//;

  $seq_output_content = "<tr><td><a target=\"blank\" href=\"$tmp_seq_file\">All Sequences (No gap)</a></td></tr>";
}


if (defined $align_seq_ref) {

  my $tmp_align_seq_file = new File::Temp(
					  DIR => $path,
					  SUFFIX => '.txt',
					  UNLINK => 0,
					 );

  my %alignment_seqs = %$align_seq_ref;
  my $seq_io_obj = Bio::SeqIO->new('-fh' => $tmp_align_seq_file,
				   '-format' => 'fasta');
  foreach (@family_member_ids) {
    my $comp_id = $_ . '-' . $species{$_};
    $comp_id =~ s/\s/_/g;
    my $seq_obj = Bio::Seq->new(
				'-seq' => $alignment_seqs{$_},
				'-id' => $comp_id
			       );
    $seq_io_obj->write_seq($seq_obj);
  }
  close $tmp_align_seq_file;

  $tmp_align_seq_file =~ s/$html_root_path//;

  my $pass_tmp_align_seq_file = $html_root_path . $tmp_align_seq_file;

  $seq_output_content .= "<tr><td><a target=\"blank\" href=\"$tmp_align_seq_file\">All Alignment Sequences (Padded with gap)</a></td>";

  my $title = 'Family ' . $family_id;
  $seq_output_content .= "<td><a target=\"blank\" href=\"/tools/align_viewer/show_align.pl?format='fasta'&amp;temp_file=$pass_tmp_align_seq_file&amp;type=nt&amp;start_value=1&amp;end_value=10000&amp;title=$title\">Analyze and Optimize with Alignment Viewer.</a></td></tr>";
}

if ($overlap_len > 0) {
  my %ol_seqs = %$ol_seq_ref;

  my $tmp_ol_seq_file = new File::Temp(
				       DIR => $path,
				       SUFFIX => '.txt',
				       UNLINK => 0,
				      );
 
  my $ol_seq_io_obj = Bio::SeqIO->new(
				      '-fh' => $tmp_ol_seq_file,
				      '-format' => 'fasta'
				     );

  foreach (@family_member_ids) {
    my $comp_id = $_ . '_' . $species{$_};
    my $seq_obj = Bio::Seq->new(
				'-seq' => $ol_seqs{$_},
				'-id' => $comp_id
			       );
    $ol_seq_io_obj->write_seq($seq_obj);  
  }
  close $tmp_ol_seq_file;

  $tmp_ol_seq_file =~ s/$html_root_path//;
  $seq_output_content .= "<tr><td><a target=\"blank\" href=$tmp_ol_seq_file>Overlap Sequences</a></td></tr>";

}


#####################################################
#Retrieve tree information
$family_tree_log_q->execute($family_id);
if (my ($taxa_num, $ol_len, $lf_loc) = $family_tree_log_q->fetchrow_array()) {
  $gene_tree_content = "<tr><td colspan=\"2\" align=\"center\"><a target=\"blank\" href=\"/about/fam_tree_analysis.pl\">For help with gene tree construction, please click here.</a></td></tr>";
  $gene_tree_content .= "<tr><th>No. of Taxa</th><td>$taxa_num</td></tr>";
  $gene_tree_content .= "<tr><th>No. of Characters</th><td>$ol_len</td></tr>";
  $gene_tree_content .= "<tr><th>Log File</th><td><a href=\"$lf_loc\">View</a></td></tr>";

  $family_tree_nw_q->execute($family_id);
  while (my ($tree_nr, $nw) = $family_tree_nw_q->fetchrow_array()) {
    my $tree_title = 'Family ' . $family_id . ' Tree No. ' . $tree_nr;
    $gene_tree_content .= "<tr><th>Tree No. $tree_nr</th><td>$nw<br><br><a target=\"blanc\" href=\"/tools/tree_browser/?tree_string=$nw&amp;title=$tree_title\">View in Tree Browser</a><br><br></td></tr>";
  }
}
else {
  $gene_tree_content = "<tr><td>No tree available</td></tr>";
}


######################################################
#Page output
$page->header();
print page_title_html("Gene Family $family_id Alignment Details");

print blue_section_html('Family Sequence Alignment','<table width="100%" cellpadding="5" cellspacing="0" border="0">'.$align_content.'</table>');

print blue_section_html('Summary','<table width="80%" cellpadding="5" cellspacing="0" border="0">'.$sum_content.'</table>');

print blue_section_html('Putative Splice Variant Pairs','<table width="100%" cellpadding="5" cellspacing="0" border="0">'.$sv_content.'</table>');

print blue_section_html('Putative Allele Pairs','<table width="100%" cellpadding="5" cellspacing="0" border="0">'.$al_content.'</table>');

print blue_section_html('Aligment Analysis','<table width="100%" cellpadding="5" cellspacing="0" border="1">'.$seq_sum_content.'</table>');

print blue_section_html('Output Sequences','<table width="100%" cellpadding="5" cellspacing="0" border="0">'.$seq_output_content.'</table>');

print blue_section_html('Family Gene Tree','<table width="100%" cellpadding="5" cellspacing="0" border="1">'.$gene_tree_content.'</table>');


$page->footer();

sub empty_search {
  my ($page, $family_id) = @_;

  $page->header();

  print <<EOF;

  <b>No family id specified</b>

EOF

  $page->footer();
  exit 0;
}

sub not_applicable {
  my ($page, $family_id, $num) = @_;

  $page->header();

  print <<EOF;

  <b>The specified $family_id has only $num valid member so that alignment is not applicable.</b>

EOF

  $page->footer();
  exit 0;
}

sub large_size {
  my ($page, $family_id, $num) = @_;

  $page->header();

  print <<EOF;

  <b>The specified $family_id has $num valid members.  Alignment is available for families having up to $family_size_limit members.</b>

EOF

  $page->footer();
  exit 0;
}
