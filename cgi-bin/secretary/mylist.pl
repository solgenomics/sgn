#!/usr/bin/perl
use strict;
use CXGN::Page::Secretary;
use CXGN::Secretary::Gene;
use CXGN::Secretary::Family;

my $page = CXGN::Page::Secretary->new("Secretary", "Chris");
my $dbh = $page->{dbh};
CXGN::Secretary::Gene->setDBH($dbh);
CXGN::Secretary::Family->setDBH($dbh);

if($page->{logout}) { $page->client_redirect("index.pl?logout=1"); }
$page->header("Secretary", "My Hotlist");

print<<HTML;
<table width='100%'>
<tr>
<td style='vertical-align:bottom; text-align:left'>
<a href='index.pl' style='text-decoration:none'><span style='font-size: 36px;'><span style='color:#ff3366;'>Secret</span><span style='color:green'>ary</span></span></a>
</td>
HTML

print <<HTML;
<td>
<center><div style="text-align:center"><br>
<form action='query.pl' method="GET" name='fqtop' style="margin:0;white-space:nowrap">
<input type="textbox" name='query' size=40 id='query_focus' value=''>
<input type="submit" value="Search">
</form></div></center></td>
</tr></table>
<h2 style='color:#444'>My Lists</h2></center>
HTML

my @agi_list = ();
if($page->{validUser}){
	my $list_text = "";
	my $hotlist = $page->set_hotlist();
	my $null = 1;
	foreach my $item (@{$hotlist->get_item_contents()}) {
		$null = 0;
		if($item =~ /AT[1-5MC]G\d+\.\d+/){
			my $agi = $item;
			push(@agi_list, $agi);
			my $gene = CXGN::Secretary::Gene->new($agi, $page);
			$gene->fetch();
			$gene->hideElements("relevancy");
			$list_text .= $gene->queryView();
		}
	}
print '<script language="javascript">';
print "\nFasta.addAgi('$_');" foreach(@agi_list);
print '</script>';

	if($null){
	print <<HTML;
	<center>
	<div class='errorbox'>
	<div class='errorboxinset'>
		No AGIs in Hotlist
	</div>
	</div>
	</center>
HTML
	}
	else{
	print<<HTML;
	<center>

<div style='width:90%'>


<table cellspacing="0" style="text-align:left;border:2px solid #990011; color:#333333;">

<tr>
<td style="padding-left:5px; background-color:#990011;color:white;width:100%"><span style="font-weight:bold;font-size:1.1em">Hotlist</span>
&nbsp;&nbsp;&nbsp;
Get FASTA: &nbsp;
<span style="font-weight:bold">
<a href="#" class="internal" style="color:white" onclick="
	Fasta.request('protein');
	return false;">Protein</a>&nbsp;
<a href="#" class="internal" style="color:white" onclick="
	Fasta.request('cds');
	return false;">CDS</a>&nbsp;
<a href="#" class="internal" style="color:white" onclick="
	Fasta.request('cdna');
	return false;">cDNA</a>&nbsp;
<a href="#" class="internal" style="color:white" onclick="
	Fasta.request('genomic');
	return false;">Genomic</a>&nbsp;
</span>

</td>
</tr>

<tr>
<td>
<center>

<div id="hotlist_fasta_content" style="
	display:none;background-color:#ddf;
	border:1px dotted grey; 
	border-top:0px;	
	width:80%;
	overflow:auto"> 
<div style="width:100%;text-align:right">
<a href="#" onclick="
	document.getElementById('hotlist_fasta_content').style.display = 'none';return false">(x) Close</a>
</div>
<a href="#" onclick="
	document.getElementById('hotlist_fasta_textarea').select();
	return false;
">Highlight All</a><br />
<textarea id="hotlist_fasta_textarea" cols="60" rows="10">&nbsp;
</textarea>
</div>



<form id="cds_align_form" target="_SGN_NEW" action="http://sgn-devel.sgn.cornell.edu/tools/align_viewer/show_align.pl" method="POST" style="margin:0px">
<textarea name="seq_data" style="display:none">
HTML

my $family = CXGN::Secretary::Family->new();

$family->addAgis(@agi_list);
$family->fetch();
print $family->FASTA("cds");

print <<HTML;
</textarea>
<input type="hidden" name="format" value="fasta_unaligned">
<input type="hidden" name="title" value="Hotlist">
<input type="hidden" name="type" value="cds">

<a href="#" onclick="
	document.getElementById('cds_align_form').submit();
	return false;">
Align CDS with Muscle v3.6</a>
</form>


</center>
</td>
</tr>

<tr>
<td style="padding:4px;width:100%;font-size:0.75em">
			$list_text
</td>
</tr>
</table>


</div>
</center>

HTML
	}
}
else {
	print<<HTML;
	<br><br>
	<center>
	<div class='errorbox'>
	<div class='errorboxinset'>
	You must be logged in to see your hotlist
	</div>
	</div>
	</center>
HTML
}

