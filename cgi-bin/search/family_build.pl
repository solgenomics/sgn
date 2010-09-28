
#!/usr/bin/perl -w
use strict;
use warnings;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;
use GD::Graph::bars;
use GD::Text;
use GD;
use File::Temp;
use CXGN::DB::Connection;
use CatalystX::GlobalContext '$c';

my $page = CXGN::Page->new( "SGN Gene Family Build", "Chenwei Lin");
my ($family_build_sum_q, $total_family_q, $total_gene_q, $other_build_q, $organism_member_q, $family_organism_q, $family_size_q);
my ($family_build_id, $family_build_nr) = $page->get_arguments("family_build_id", "family_build_nr");


my $dbh = CXGN::DB::Connection->new("public");

if($family_build_nr && !$family_build_id) {
	my $fam_id_q = $dbh->prepare("SELECT family_build_id FROM family_build WHERE build_nr=?");
	$fam_id_q->execute($family_build_nr);
	($family_build_id) = $fam_id_q->fetchrow_array();
}

empty_search($page) unless $family_build_id;

$family_build_sum_q = $dbh->prepare("select family_build.group_id, i_value, build_date, comment, build_nr from family_build left join sgn.groups using (group_id) where family_build_id = ?");

$total_family_q = $dbh->prepare("select count(family_id) from family where family_build_id = ?");
$total_gene_q = $dbh->prepare("select count(family_member_id) from family left join family_member using (family_id) where family_build_id = ?");

$other_build_q = $dbh->prepare("
	SELECT family_build_id, build_nr, i_value 
	FROM family_build 
	WHERE group_id = ? 
	AND build_nr != ?
	AND status='C'	
	");

$family_organism_q = $dbh->prepare("select family_member.family_id,organism_group_id, comment from sgn.groups left join family_member on (family_member.organism_group_id = sgn.groups.group_id) left join family using (family_id) left join family_build using (family_build_id) where family_build.family_build_id = ?");

$family_size_q = $dbh->prepare("select count(family_member_id) from family_member left join family using (family_id) where family_build_id = ? group by family_member.family_id");


my ($sum_content, $member_content, $other_build_content, $dist_content);
###############################################
#Family build summary
$family_build_sum_q->execute($family_build_id);
my ($group_id, $i_value, $build_date, $group_comment, $build_nr, $total_family, $total_gene);
my ($i_value_content, $date_content, $group_comment_content, $build_nr_content, $total_family_content, $total_gene_content);

if (($group_id, $i_value, $build_date, $group_comment, $build_nr, $total_family) = $family_build_sum_q->fetchrow_array()){
  my $date_content = substr($build_date, 0, 10);
  if ($i_value < 2){
    $i_value_content =  $i_value . "  (Low stringency in grouping genes together)";
  }
  elsif ($i_value >= 2 && $i_value < 5){
    $i_value_content = $i_value . "  (Normal stringency in grouping genes together)";
  }
  elsif ($i_value >= 5){
    $i_value_content =  $i_value . "  (High stringency in grouping genes together)";
  }
  else { $i_value_content = $i_value }

  $total_family_q->execute($family_build_id);
  ($total_family) = $total_family_q->fetchrow_array();
  $total_gene_q->execute($family_build_id);
  ($total_gene) = $total_gene_q->fetchrow_array();
  $date_content = "<tr><th>Build Date</th><td>" . $date_content . "</td></tr>";
  $i_value_content = "<tr><th>i Value</th><td> ". $i_value_content . "</td></tr>"; 
  $group_comment_content = "<tr><th>Data Set</th><td>" . $group_comment . "</td></tr>";
  $build_nr_content = "<tr><th>Build number</th><td>" . $build_nr . "</td></tr>";
  $total_family_content = "<tr><th>Total Families</th><td>" . $total_family . "</td></tr>";
  $total_gene_content = "<tr><th>Total Genes/Unigenes</th><td>" . $total_gene . "</td></tr>";
  $sum_content = $date_content . $i_value_content . $group_comment_content . $build_nr_content . $total_family_content . $total_gene_content;
  $sum_content .= "<tr><td colspan=\"2\" align=\"center\" bgcolor=\"gray\"><a href=\"/about/family_analysis.pl\" target=\"blank\">For help with gene family analysis, please click here.</a></td></tr>";
}
else {
  &invalid_search;
}

###############################################
#Member datasets
my %organism_gene_count = ();
my %organism_family = ();
my %family_organism = ();
my %organism_uniq_family_count = ();
my %organism_comment = ();
my %organism_family_count = ();

$family_organism_q->execute($family_build_id);
while (my ($family_id, $organism_group_id, $organism_group_comment) = $family_organism_q->fetchrow_array()){
  $organism_comment{$organism_group_id} = $organism_group_comment;
  if (!defined $organism_gene_count{$organism_group_id}){
    $organism_gene_count{$organism_group_id} = 1;
  }
  else {
    $organism_gene_count{$organism_group_id}++;
  }
  $organism_family{$organism_group_id}{$family_id} = 1;
  $family_organism{$family_id}{$organism_group_id} = 1;
}

foreach (keys %organism_family){
  $organism_family_count{$_} = 0;
  my $count = int (keys %{$organism_family{$_}});
  $organism_family_count{$_} += $count;
}

foreach (keys %family_organism){
  my $count = int (keys %{$family_organism{$_}});
  my $family_id = $_;
  if ($count == 1){
    foreach (keys %{$family_organism{$family_id}}){
      if (!defined $organism_uniq_family_count{$_}){
	$organism_uniq_family_count{$_} = 1;
      }
      else {
	$organism_uniq_family_count{$_}++;
      }
    }
  }
}
  
my $member_data_content = "<tr><th>Species</th><th># Genes or Unigenes</th><th># Families</th><th># Unique Families</th></tr>";
foreach (sort {$organism_gene_count{$b} <=> $organism_gene_count{$a}} keys %organism_gene_count){
  $member_data_content .= "<tr><td>$organism_comment{$_}</td><td>$organism_gene_count{$_}</td><td>$organism_family_count{$_}</td><td>$organism_uniq_family_count{$_}</td></tr>";
}


###############################################
#Other builds of the same group
my %other_build = ();
my %other_build_id = ();

$other_build_q->execute($group_id, $build_nr);
while (my ($other_build_id, $other_build_nr, $other_i_value) = $other_build_q->fetchrow_array())
{
  
  if ($other_i_value < 2){
    $other_i_value .= " (Low stringency in grouping genes together)";
  }
  elsif($other_i_value >= 2 && $other_i_value < 5){
    $other_i_value .= " (Normal stringency in grouping genes together)";
  }
  else {
    $other_i_value .= " (High stringency in grouping genes together)";
  }
  $other_build{$other_build_nr} = $other_i_value;
  $other_build_id{$other_build_nr} = $other_build_id;

}

$other_build_content = "<tr><th>Build number</th><th>i Value</th></tr>";
foreach (sort keys %other_build){
  $other_build_content .= "<tr><td><a href=\"family_build.pl?family_build_id=$other_build_id{$_}\">$_</a></td><td>$other_build{$_}</td></tr>";
}

###############################################
#Size distribution
my %size_gene_count = ();
my %size_family_count  = ();
$family_size_q->execute($family_build_id);
while (my ($count) = $family_size_q->fetchrow_array()){
  if ($count == 1) { 
    $size_gene_count{"1"}++;
  }
  elsif ($count == 2){
    $size_gene_count{"2"} += $count;
  }
  elsif ($count == 3){
    $size_gene_count{"3"} += $count;
  }
  elsif ($count >3 && $count <=20){
    $size_gene_count{"4-20"} += $count;
  }
  elsif ($count >20 && $count <=40){
    $size_gene_count{"21-40"} += $count;
  }
  elsif ($count >40 && $count <=100){
    $size_gene_count{"41-100"} += $count;
  }
  else {
    $size_gene_count{"100 up"} += $count;
  }
}
  
###############################################
#Draw bar chart
#First generte a random file.
my $html_root_path = $c->config->{'basepath'};
my $doc_path = $c->tempfiles_subdir('family_images');
my $path = $html_root_path . $doc_path;
my $tmp = new File::Temp(
                        DIR => $path,
                        SUFFIX => '.png',
                        UNLINK => 0,
                    );

#Draw the bar chart  
my $graph = new GD::Graph::bars(700, 400);

$graph->set(
		   x_label => 'Family Size',
		   y_label => '%',
		   dclrs => [ qw(lblue) ],
		   bar_spacing => 10,
		   x_labels_vertical => 1,
		   x_label_position => 0.5,
		   text_space => 16,
                   two_axes => 1,
                   bar_width => 5,
		   
);

$graph->set_x_label_font(gdGiantFont);
$graph->set_y_label_font(gdGiantFont);
$graph->set_x_axis_font(gdMediumBoldFont);
$graph->set_y_axis_font(gdMediumBoldFont);
$graph->set_legend_font(gdGiantFont);
my @x_values = ();
my @y_values = ();

foreach (sort {$a<=>$b} keys %size_gene_count){
  push @x_values, $_;
  push @y_values, $size_gene_count{$_} / $total_gene * 100;
}
  
my $gd = $graph->plot([\@x_values, \@y_values]);
print $tmp $gd->png;
$tmp =~ s/$html_root_path//;
close $tmp;

my $size_content = "<tr><td><center><img src=\"$tmp\" alt=\"\" /></center></td></tr>";

###############################################
#Page printout
$page->header();
print page_title_html("SGN Gene Family Build $family_build_id");
print blue_section_html('Summary','<table width="100%" cellpadding="5" cellspacing="0" border="0">' . $sum_content . '</table>');
print blue_section_html('Member Data Sets','<table width="100%" cellpadding="5" cellspacing="0" border="1">' . $member_data_content . '</table>');
print blue_section_html('Other Builds with Different Inflation Factor','<table width="100%" cellpadding="5" cellspacing="0" border="0">' . $other_build_content . '</table>');
print blue_section_html('Unigene Family Size Distribution','<table width="100%" cellpadding="5" cellspacing="0" border="0" align="center">' . $size_content . '</table>');


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
  my ($page, $family_build_id) = @_;

  $page->header();

  print <<EOF;

  <b>The specified family identifer ($family_build_id) does not result in a valid search.</b>

EOF

  $page->footer();
  exit 0;
}

