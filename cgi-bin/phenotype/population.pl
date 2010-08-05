#!/usr/bin/perl -w

#Main Page for Phenotypic Database

use strict;
use CXGN::Page;
use CXGN::DB::PhenoPopulation;
use CGI;

#get parameters from form on previous page
use CatalystX::GlobalContext qw( $c );
my %params = %{$c->req->params};
my $pop_id = $params{pop_id};

my $page = CXGN::Page->new('phenotype', 'Adri');

print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 transitional//EN\" \"http://www.w3.org/tr/xhtml1/DTD/xhtml1-transitional.dtd\">";

#-------------------------------------------------
my @populations = CXGN::DB::PhenoPopulation::get_all_populations;
my $current_pop_id;
my $current_pop_name;

#population selected
if ($pop_id) {
  $current_pop_id = $pop_id;
  $current_pop_name = CXGN::DB::PhenoPopulation::get_pop_name_from_pop_id($pop_id);
}

#no population selected, first one in DB is used as default
else {
  $current_pop_id = $populations[0][0];
  $current_pop_name = $populations[0][1];
}

my @genotypes = CXGN::DB::PhenoPopulation::get_all_gen_from_pop_id($current_pop_id);
my @gen_ids;
for my $i (0..$#genotypes) {
  push @gen_ids, $genotypes[$i][0];
}
my @prop_info_by_organ = CXGN::DB::PhenoPopulation::get_all_prop_info_by_organ_from_pop_id($current_pop_id);

$page->header($current_pop_name." Population");

print <<EOF

<table summary="" width="100%" cellpadding="0" cellspacing="10" border="0">

<tr><td valign="top">
<center><h2><b><u>$current_pop_name Population</u></b></h2></center>
</td></tr>
EOF
;

#select box for populations
if ($#populations > 0) {
  print "<tr><td valign=\"top\">";
  print "<table summary=\"\"><tr><td colspan=\"2\">";
  print "<form action=\"/phenotype/main_phenotype.pl\" method=\"get\">";
  print "<br />";
  print "<b><u>Change Population</u></b>\n<br />";
  print "Below is the list of population(s) currently in the database.  Select a population and click the button to search images and data in another population.";
  print "</td></tr>";
  print "<tr><td valign=\"top\" align=\"left\">";
  print "All Populations:  ";
  print "<select name=\"pop_id\">\n";
  for my $i (0..$#populations) {
    print "<option value=\"$populations[$i][0]\"> $populations[$i][1]</option>";
  }
  print "</select>";
  print "</td>";
  print "<td valign=\"top\" align=\"right\">";
  print "<input type=\"submit\" value=\"Change Population\" />";
  print "<br />";
  print "</form>";
  print "</td></tr></table>";
  print "</td></tr>";

  #line
  print "<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"10\" alt=\"\" /></td></tr>";
  print "<tr><td colspan=\"1\" bgcolor=\"#cccccc\"><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"1\" alt=\"\" /></td></tr>";
  print "<tr><td><img src=\"/documents/img/dot_clear.gif\" width=\"1\" height=\"10\" alt=\"\" /></td></tr>";
}

print <<EOF
<tr><td valign="top">

<table summary="" width="100%" cellpadding="0" cellspacing="0" border="0">

<!--genotypes-->
<tr><td colspan="2">
<form action="/phenotype/display_plants_from_genotype.pl" method="get">
<table summary="" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr><td>
<b><u>Search By GENOTYPES</u></b>
</td></tr>
<tr><td>
Below is a list of all <b>genotypes</b> in the selected population above - selecting a genotype will take you to a page of plants with the selected genotype.  This new page will have links to all images and data of these plants:
</td></tr>
<tr><td valign="top" align="left">
Genotypes in <b>$current_pop_name</b>:
<select name="gen_id">

EOF
;

for my $i (0..$#genotypes) {
  print "<option value = \"$genotypes[$i][0]\"> $genotypes[$i][1]</option>";
}

print <<EOF
</select>
<input type="hidden" name="pop_id" value="$current_pop_id" />
<input type="hidden" name="pop_name" value="$current_pop_name" />
</td>
<td valign="top" align="right">
<input type="submit" value="get Plants by Genotype" />
</td></tr>
</table>
</form>
</td></tr>
EOF
    ;

my $current_pop_name_2 = $current_pop_name;
$current_pop_name_2 =~ s/\s/%20/g;

print<<EOF

<!--properties-->
<tr><td colspan="2">
<form action="/phenotype/display_plants_from_property.pl" method="get">
<table summary="">
<tr><td>
<b><u>Search By PROPERTIES</u></b> (<a href="display_prop_list.pl?pop_id=$current_pop_id&amp;pop_name=$current_pop_name_2">Property Descriptions</a>)
</td></tr>

EOF
;

print "<tr><td>Below is a list of all <b>properties</b> measured in the selected population above - selecting a property will take you to a page of plants with the selected property measured.  This new page will have links to each plant's sample data and images:</td></tr>";

print "<tr><td width=\"100%\" valign=\"top\" align=\"left\">";
print "Properties in <b>$current_pop_name</b>:";
print "<select name=\"prop_id\">";

for my $i (0..$#prop_info_by_organ) {
  $prop_info_by_organ[$i] or next;

  my $organ_name = $prop_info_by_organ[$i][0][2];
  print "<optgroup label=\"$organ_name\">";
  for my $j (0..$#{$prop_info_by_organ[$i]}) {
    my $prop_id = $prop_info_by_organ[$i][$j][0];
    my $prop_name = $prop_info_by_organ[$i][$j][1];
    print "<option value=\"$prop_id\"> $prop_name</option>";
  }
  print "</optgroup>";
}

print <<EOF
</select>
<input type="hidden" name="pop_id" value="$current_pop_id" />
<input type="hidden" name="pop_name" value="$current_pop_name" />
</td>
<td width="100%" valign="top" align="right">
<input type="submit" value="get Plants by Property" />
</td></tr>
</table>
</form>
</td></tr>

<tr><td><img src="/documents/img/dot_clear.gif" width="1" height="10" alt="" /></td></tr>
<tr><td colspan="1" bgcolor="#cccccc"><img src="/documents/img/dot_clear.gif" width="1" height="1" alt="" /></td></tr>
<tr><td><img src="/documents/img/dot_clear.gif" width="1" height="10" alt="" /></td></tr>

<tr><td>
<center><h3><u>Terminology</u></h3></center>
</td></tr>
<tr><td>
  <dl>
  <dt><b>Population</b></dt>
  <dd>all the organisms that constitute a specific group or occur in a specified location</dd>
  <dt><br /><b>Genotype</b></dt>
  <dd>a group of organisms sharing a specific genetic constitution</dd>
  <dt><br /><b>Property/Phenotype</b></dt>
  <dd>the observable physical or biochemical characteristics of an organism, as determined by both genetic makeup and environmental influences</dd>
  </dl>

</td></tr>
</table>
</td></tr>
</table>

EOF
;

$page->footer();
