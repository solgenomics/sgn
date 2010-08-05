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

$page->header("Search the Phenotype Database");

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

print <<EOF

<table summary="" width="100%" cellpadding="0" cellspacing="10" border="0">

<tr><td valign="top">
<table summary="" width="100%" cellpadding="0" cellspacing="0" border="0">

<tr><td>
<center>
<h3><u>Welcome to the Phenotype Database</u></h3>
<p>From this page, you can search the phenotype databse for data and images of all plants from all populations.</p>
<p>There are two ways to find specific data and images: searching by genotype and phenotype.</p>
</center>
</td></tr>

<tr><td><img src="/documents/img/dot_clear.gif" width="1" alt="" height="10" /></td></tr>
<tr><td colspan="1" bgcolor="#cccccc"><img src="/documents/img/dot_clear.gif" alt="" width="1" height="1" /></td></tr>
<tr><td><img src="/documents/img/dot_clear.gif" width="1" height="10" alt="" /></td></tr>

<tr><td>
<center><h3><u>Search the Phenotype Database</u></h3></center>

<center>
<table summary="" width="100%" cellpadding="0" cellspacing="0" border="0">

<tr><td>
<!--populations-->
<form action="#" method="get">
<table summary="">
<tr><td valign="top">

EOF
;

print "<b><u>selected POPULATION:</u> $current_pop_name</b>";

print <<EOF
</td></tr>
<tr><td><p>Below is the list of population(s) currently in the database. Select a population and click the button to search images and data in another population.</p></td></tr>
<tr><td valign="top" align="left">
All Populations:
<select name="pop_id">
EOF
;

for (0..$#populations) {
  print "<option value = \"$populations[$_][0]\">$populations[$_][1]</option>";
}

print <<EOF
</select>
</td>
<td valign="top" align="right">
<input type="submit" value="Change Population" />
</td></tr>
</table>
</form>
</td></tr>

<!--genotypes-->

<tr><td>
<form action="/phenotype/display_plants_from_genotype.pl" method="get">
<table summary="">
<tr><td>
<b><u>Search By GENOTYPES</u></b>
</td></tr>
<tr><td><p>Below is a list of all <b>genotypes</b> in the selected population above -  
selecting a genotype will take you to a page of plants with the selected genotype.  This new page will have links to all images and data of these plants:</p></td></tr>
<tr><td valign="top" align="left">

EOF
;

print "Genotypes in <b>$current_pop_name</b>:";
print "<select name=\"gen_id\">";
for my $i (0..$#genotypes) {
  print "<option value = \"$genotypes[$i][0]\"> $genotypes[$i][1]</option>";
}
print "</select>";
print "<input type=\"hidden\" name=\"pop_id\" value=\"$current_pop_id\" />";
print "<input type=\"hidden\" name=\"pop_name\" value=\"$current_pop_name\" />";

print <<EOF
</td>
<td valign="top" align="right">
<input type="submit" value="get Plants by Genotype" />
</td></tr>
</table>
</form>
</td></tr>

<!--properties-->
<tr><td>
<form action="/phenotype/display_plants_from_property.pl" method="get">
<table summary=""><tr><td>
<b><u>Search By PROPERTIES</u></b> (<a href="display_prop_list.pl">Property Descriptions</a>)
</td></tr>
<tr><td>
EOF
;

print "<p>Below is a list of all <b>properties</b> measured in the selected population above - 
selecting a property will take you to a page of plants with the selected property measured.  This new page will have links to each plant's sample data and images:</p>";

print "</td></tr>";
print "<tr><td width=\"100%\" valign=\"top\" align=\"left\">";

print "Properties in <b>$current_pop_name</b>:";
print "<select name=\"prop_id\">";

for (0..$#prop_info_by_organ) {
  my $i = $_;
  $prop_info_by_organ[$i] or next;
  my $organ_name = $prop_info_by_organ[$i][0][2];
  print "<optgroup label=\"$organ_name\">";
  for (0..$#{$prop_info_by_organ[$i]}) {
    my $j = $_;
    my $prop_id = $prop_info_by_organ[$i][$j][0];
    my $prop_name = $prop_info_by_organ[$i][$j][1];
    print "<option value = \"$prop_id\">$prop_name</option>\n";
  }
  print "</optgroup>";
}

print "</select>";
print "<input type=\"hidden\" name=\"pop_id\" value=\"$current_pop_id\" />";
print "<input type=\"hidden\" name=\"pop_name\" value=\"$current_pop_name\" />";

print <<EOF

</td>
<td width="100%" valign="top" align="right">
<input type="submit" value="get Plants by Property" />
</td></tr></table>
</form>
</td></tr>

</table>
</center>
</td>
</tr>

</table>
</td></tr>

<tr><td><img src="/documents/img/dot_clear.gif" width="1" height="10" alt="" /></td></tr>
<tr><td bgcolor="#cccccc"><img src="/documents/img/dot_clear.gif" width="1" height="1" alt="" /></td></tr>
<tr><td><img src="/documents/img/dot_clear.gif" width="1" height="10" alt="" /></td></tr>

<!--terminology-->
<tr><td>
<center><h3><u>Terminology</u></h3></center>

<table summary="" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr><td>

<dl>
<dt><b>Population</b></dt>
<dd>all the organisms that constitute a specific group or occur in a specified location.</dd>
<dt><br /><b>Genotype</b></dt>
<dd>a group of organisms sharing a specific genetic constitution.</dd>
<dt><br /><b>Property/Phenotype</b></dt>
<dd>the observable physical or biochemical characteristics of an organism, as determined by both genetic makeup and environmental influences.</dd>
</dl>

</td></tr>
</table>

</td></tr>

</table>
EOF
;

#--------------------------
$page->footer();
