#!/usr/bin/perl -w
use strict;
use warnings;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
									   info_section_html
                                       blue_section_html  /;
use CXGN::DB::Connection;
use CXGN::Phylo::Alignment;
use CXGN::Tools::Identifiers;
use CXGN::Tools::WebImageCache;
use CatalystX::GlobalContext '$c';
use File::Temp;

our $page = CXGN::Page->new( "SGN Gene Family", "Chenwei Lin");
our ($sum_q, $at_family_member_q, $sgn_family_member_q, $organism_group_q, $other_family_q, $sgn_align_seq_q, $at_align_seq_q);


my $dbh = CXGN::DB::Connection->new("sgn");

$sum_q = $dbh->prepare("
	SELECT 
		family_build.family_build_id, 
		family_build.status,
		count(family_member_id), 
		build_date, 
		build_nr, 
		i_value, 
		family_annotation, 
		family_build.group_id, 
		comment,
		family.family_nr
	FROM sgn.family_member 
	LEFT JOIN sgn.family USING (family_id) 
	LEFT JOIN sgn.family_build USING (family_build_id) 
	LEFT JOIN sgn.groups USING (group_id) 
	WHERE family.family_id = ? 
	GROUP BY family.family_id, family.family_nr, family_build.family_build_id, family_build.status, build_date, build_nr, i_value, family_annotation, group_id, comment");

$at_family_member_q = $dbh->prepare("
	SELECT sequence_name 
	FROM family_member 
	WHERE family_id = ? 
	AND database_name LIKE 'Arabidopsis'");

$sgn_family_member_q = $dbh->prepare("
	SELECT unigene_id, family_member.cds_id, organism_group_id 
	FROM sgn.family_member 
	LEFT JOIN sgn.cds USING (cds_id) 
	WHERE family_id = ? 
	AND (	database_name LIKE 'SGN' 
			OR database_name LIKE 'CGN'
		)
	");

$organism_group_q = $dbh->prepare("
	SELECT comment 
	FROM sgn.groups 
	WHERE group_id = ?");

$other_family_q = $dbh->prepare("
	SELECT family_member.family_id, build_nr, i_value, member_count, family_nr
	FROM sgn.family_member 
	LEFT JOIN sgn.family USING (family_id) 
	LEFT JOIN sgn.family_build USING (family_build_id) 
	WHERE cds_id = ? 
	AND family_member.family_id != ? 
	AND group_id = ?
	AND status='C'	
	");

my $family_size_align_limit = 200;

my ($family_id, $family_nr, $i_value) = $page->get_arguments(qw/ family_id family_nr i_value/ );
if ($family_id eq ""){
	empty_search($page) unless ($family_nr && $i_value);
	my $family_id_q = $dbh->prepare("
		SELECT family_id
		FROM sgn.family
		LEFT JOIN sgn.family_build USING(family_build_id)
		WHERE 
		family_nr=?
		AND family_build.i_value=?");
	$family_id_q->execute($family_nr, $i_value);
	($family_id) = $family_id_q->fetchrow_array();
	empty_search($page) unless $family_id;
}

my ($sum_content, $member_content, $link_content, $align_content);


##################################
#Get information for the summary section

my ($annotation_content, $family_nr_content, $date_content, $i_value_content, $bn_content, $group_content, $total_gene_content);
my ($family_build_id, $family_build_status, $total_gene, $date, $build_nr, $i_value, $annotation, $group_id, $group_comment, $family_nr);
$sum_q->execute($family_id);
if (($family_build_id, $family_build_status, $total_gene, $date, $build_nr, $i_value, $annotation, $group_id, $group_comment, $family_nr) = $sum_q->fetchrow_array()){
  my $date_display = substr ($date, 0,10);
  $total_gene_content = "<tr><th>Total Genes</th><td>" . $total_gene . "</td></tr>";
  $date_content = "<tr><th>Build Date</th><td>" . $date_display . "</td></tr>";
  $family_nr_content = "<tr><th>Family&nbsp;Number</th><td>" . $family_nr . "</td></tr>";
  if ($i_value < 2){
    $i_value_content =  $i_value . "  (Low stringency in grouping genes together)";
  }
  elsif ($i_value >=2 && $i_value < 5){
    $i_value_content = $i_value . "  (Normal stringency in grouping genes together)";
  }
  elsif ($i_value >= 5){
    $i_value_content =  $i_value . "  (High stringency in grouping genes together)";
  }
    
  $i_value_content = "<tr><th>i Value</th><td> ". $i_value_content . "</td></tr>";
  $bn_content = "<tr><th>Build</th><td>" . $build_nr . " <a href=\"family_build.pl?family_build_id=$family_build_id\">[Details of the Overall Family Build]</a>" . "</td></tr>";
  $annotation_content = "<tr><th valign=\"top\">Annotation</th><td>" . $annotation . "</td></tr>";
  $group_content = "<tr><th>Data Set</th><td>" . $group_comment . "</td></tr>";
}
my $deprecated_content = '';
if($family_build_status ne 'C'){
	$deprecated_content .= "<center><div class=\"deprecated\" style=\"width:550px\">This family is from an out-of-date build.  <br />";
	$deprecated_content .= "<span style=\"color:black;font-size:0.9em\">See below for relations to current builds</span></div></center>";
}
$sum_content = $family_nr_content . $total_gene_content . $date_content .$i_value_content . $bn_content . $annotation_content . $group_content;
$sum_content .= "<tr><td colspan=\"2\" align=\"center\"><a href=\"/about/family_analysis.pl\" target=\"blank\">
Explanation of family analysis and terms used on this page
</a></td></tr>";
####################################################
#Get family member information.
my $at_member_nr;
my @at_member_url = ();
my @at_member = ();
my %sgn_member = ();
my @all_sgn_member = ();
my %group_comment = ();
my %group_member_nr = ();
my $family_member_content;

$at_family_member_q->execute($family_id);
while( my ($member) = $at_family_member_q->fetchrow_array()){
  my $locus = substr ($member, 0,9);
  my $member_url = CXGN::Tools::Identifiers::link_identifier($locus);
#  my $member_url  = "<a href=\"http://www.arabidopsis.org/servlets/TairObject?type=locus&amp;name=$locus\" target=\"blank\">" . $member . "</a>";
  push @at_member_url, $member_url;
  push @at_member, $member;
}
$at_member_nr = int (@at_member);

$sgn_family_member_q->execute($family_id);
while( my ($member, $cds_id, $organism_group_id) = $sgn_family_member_q->fetchrow_array()){
  push @{$sgn_member{$organism_group_id}}, $member;
  push @all_sgn_member, $cds_id;
}

foreach (keys %sgn_member){
  $organism_group_q->execute($_);
  if (my ($comment) = $organism_group_q->fetchrow_array()){
    $group_comment{$_} = $comment;
    $group_member_nr{$_} = int @{$sgn_member{$_}};
  }
}

my %sgn_member_content = ();
foreach (sort keys %sgn_member){
  my $id = $_;
  foreach (@{$sgn_member{$id}}){
	$sgn_member_content{$id} .= CXGN::Tools::Identifiers::link_identifier("SGN-U" . $_) . " ";
	#"<a href=\"unigene.pl?unigene_id=$_\">SGN-U" . $_ . "</a>  ";
  }
}

$family_member_content = "<tr><th>Organism</th><th># of Members</th><th>Member Id</th></tr>";
$family_member_content .= "<tr><td>Arabidopsis</td>" . "<td>$at_member_nr</td>" . "<td>@at_member_url</td></tr>";
foreach (sort keys %sgn_member){
  $family_member_content .=  "<tr><td>$group_comment{$_}</td>" . "<td>$group_member_nr{$_}</td>" . "<td>$sgn_member_content{$_}</td></tr>";
}
 
######################################################
#Link to other families
my %other_family = ();
my %other_i = ();
my %other_size = ();
my %other_num = ();
my $other_family_content;
my $number;

#use the @all_sgn_member and $group from previous sections
my %family_regist = ();
foreach (@all_sgn_member){
  $other_family_q->execute($_, $family_id, $group_id);
  while (my ($other_family_id, $other_build, $other_i_value, $other_size, $other_family_num) = $other_family_q->fetchrow_array()){
    $other_i{$other_build} = $other_i_value;
	$other_size{$other_family_id} = $other_size;
	$other_num{$other_family_id} = $other_family_num;
    if (!defined $family_regist{$other_family_id}){
      push @{$other_family{$other_build}}, $other_family_id;
      $family_regist{$other_family_id} = 1;
    }
  }
}
my %other_family_content_family = ();
foreach (sort keys %other_family) {
  my $id = $_;
  foreach (@{$other_family{$id}}){
  	my $content = $other_num{$_};
	$content .= "(" . $other_size{$_} . ")";
    $other_family_content_family{$id} .= qq|
		<a href="family.pl?family_id=$_">$content</a>&nbsp;
		|;
  }
}
  

$other_family_content .= "<tr><th>Build id</th><th>i Value</th><th>Family Number (Size)</th></tr>";

foreach (sort keys %other_family){
  $other_family_content .= "<tr><td>$_</td>" . "<td>$other_i{$_}</td>" . "<td>$other_family_content_family{$_}</td></tr>";
}


######################################################
#Retrieve alignment sequences and draw an alignment image

##First check family size
#
my $pep_align_file = "/data/prod/public/family/$i_value/pep_align/$family_nr.pep.aligned.fasta";
my $newick_file = "/data/prod/public/family/$i_value/newick/$family_nr.newick";

my $total_member_nr = int (@all_sgn_member) + $at_member_nr;
if ($total_member_nr == 1 || $family_build_status ne 'C') {
  $align_content = "<tr><td>Not applicable.</td></tr>";
}
elsif( ! -f $pep_align_file ){
	my $extra = " due to its large size";
	$extra = "" unless ($total_member_nr > 100); #actual limit is 200, usually
	$align_content = "<tr><td>Alignment not available for this family$extra.</td></tr>";
}
elsif ($total_member_nr > $family_size_align_limit) {
  $align_content = "<tr><td>Family size too large for alignment on this page.";
  $align_content .= qq|&nbsp;&nbsp;<a href="/tools/align_viewer/show_align.pl?family_id=$family_id">See Alignment in Viewer</a> |;
  $align_content .= "</td></tr>";
}
else {
	
	my $img_height = $total_member_nr * 20;
	my $img_width = 700;

	my $cache = CXGN::Tools::WebImageCache->new();
	$cache->set_key($i_value . '_' . $family_nr);
	$cache->set_expiration_time(1);
	$cache->set_map_name("family_alignment_tree");
	$cache->set_basedir($c->config->{"basepath"});
	$cache->set_temp_dir("/documents/tempfiles/family");
	if(!$cache->is_valid()){
		my $treealign = undef;
		my $alignment = undef;	

		my $alignment_only = 1;
		$alignment_only = 0 if (-f $newick_file);

		unless($alignment_only){
			use CXGN::Phylo::Tree;
			$treealign = CXGN::Phylo::Tree->new({
				from_files => {
					newick => $newick_file,
					alignment => $pep_align_file
				}
			});
			$treealign->get_layout()->set_image_width($img_width);
			$treealign->get_layout()->set_image_height($img_height);
			$alignment = $treealign->get_alignment();
		}
		else {
			$alignment = CXGN::Phylo::Alignment->new(
				 width=>$img_width, 
				 height=>$img_height,
				 type=>'pep',
				 from_file=>$pep_align_file
			);
		}
			   
	 
		  ##Draw family_alignment image and write map file
		my $show_num = $alignment->get_nonhidden_member_nr();
		if ($show_num > 1) { 
				my $image_mode = "s";
				$image_mode = "c" if ($show_num < 60 && !-f $newick_file);
				$alignment->set_display_type($image_mode);
			
				my $tool_link = undef;
				unless($alignment_only){
					$cache->set_image_data($treealign->render_png());
					$tool_link = 'tree_browser/index.pl?&align_type=pep';
				}
				else {
					$alignment->render();
					$cache->set_image_data($alignment->{image}->png());
					$tool_link = 'align_viewer/show_align.pl?';
				}
				
			    $align_content = "<tr><td><center><a target=\"new_tab\" href=\"../tools/${tool_link}&family_nr=$family_nr&i_value=$i_value\">";
				$align_content .= $cache->get_image_html();
				$align_content .= "</a></center></td></tr>";
			    $align_content .= "<tr><td align=\"center\">Click on the image above to view the detailed alignment</td></tr>";
		}
	  	else {
	   		$align_content = "No alignment image available.";
		}
  	}
	else {
			$align_content = "<tr><td><center><a target=\"new_tab\" href=\"../tools/align_viewer/show_align.pl?family_nr=$family_nr&i_value=$i_value\">";
			$align_content .= $cache->get_image_html();
			$align_content .= "</a></center></td></tr>";
			#<img src=\"$tmp_image\" alt=\"\" border=\"0\"/></a></center></td></tr>";
		    $align_content .= "<tr><td align=\"center\">Click on the image above to view the detailed alignment</td></tr>";

	}	
}

######################################################
#Page output
$page->header();
print page_title_html("SGN Gene Family $family_id");
print $deprecated_content if $deprecated_content;
print info_section_html(title => 'Summary', contents => '<table width="100%" cellpadding="5" cellspacing="0" border="0">'.$sum_content.'</table>');
print info_section_html(title => 'Relations to Other Builds', contents => '<table width="100%" cellpadding="5" cellspacing="0" border="0">'.$other_family_content.'</table>');
print info_section_html(title => 'Family Sequence Alignment', contents => '<table width="100%" cellpadding="5" cellspacing="0" border="0">'.$align_content.'</table>');
print info_section_html(title => 'Family Members', contents => '<table width="100%" cellpadding="5" cellspacing="0" border="1">'.$family_member_content.'</table>', collapsible => 1);

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

sub invalid_search {
  my ($page, $family_id) = @_;

  $page->header();

  print <<EOF;

  <b>The specified family identifer ($family_id) does not result in a valid search.</b>

EOF

  $page->footer();
  exit 0;
}


