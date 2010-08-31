#!/usr/bin/perl -w

#######################################################
#
#page to display form to get input to SecreTary 
#
#######################################################

use strict;
use CXGN::Page;

our $page = CXGN::Page->new( "SecreTary predictor", "TomFY");

$page->header("SecreTary");

print<<END_STLOGO;
<div style="width:100%; color:#303030; font-size: 1.1em; text-align:left;">
<center>
<img style="margin-bottom:10px" src="/documents/img/secretom/secretom_logo_smaller.jpg" alt="secretom logo" />
</center>
END_STLOGO

print<<SECRETARY_TITLE;
<center>
<font size="+3"><b>SecreTary</b></font> 
<br/><br/>
<font size="+1">Computational prediction of secreted proteins.<br/><br/></font>
</center>
SECRETARY_TITLE

print <<TABLE0;
<table width="100%" border=0 bgcolor=#FFFFFF >
<tr>

<td width="16%" align=left>
<a name="tools"><strong>Links</strong></a>
<ul align=left>
<li><a href="http://www.cbs.dtu.dk/services/SignalP">SignalP</a></li>
<li><a href="http://www.predisi.de">PrediSi</a></li>
<li><a href="http://rpsp.bioinfo.pl/">RPSP</li>
<li><a href="http://phobius.sbc.su.se/">Phobius</a></li>
<li><a href="http://urgi.versailles.inra.fr/predotar/predotar.html">Predotar</a></li>
</ul>
</td>
<td width ="4%"><font color="#FFFFFF">..............</font> </td>

<td width="70%">
<table width="100%" bgcolor=#FFDD44>
<tr valign=center>
<td width="25%" align=center valign=center> <a href="prediction.pl"> Background </a></td>
<td width="25%" valign=center><a href="secretary_instructions.pl"> Instructions</a> </td>
<td width="25%"> References </td>
<td width="25%"> Data sets </td>
</tr>
</table>
<br/>

<font size="+2">
<b>Submission </b></font>
<br/>
<font size="+1">Paste one or more protein sequences in FASTA format into the field below:</font>
<br/><br/>


<form method="post" action="run_secretary.pl" name="secretary">

<textarea name="sequence" rows="10" cols="100"></textarea> <br/><br/>
 <font size="+1">Submit local FASTA file:</font>
 <input type="file" name="filename" size="28" />

<table summary="" width="98%">
<tr align=center>
<td align=left><input type="checkbox" value="Sort by score" name="sort">Sort by score</td>
<td align=left><input type="checkbox" value="show_only_sp" name="show_only_sp">Show predicted signal peptides only</td>
</tr>
<tr align=center>
    <td align=left> <input type="reset" value="Reset" /> </td>

   <td  align=right> <input type="submit" name="submit" value="Submit"/> </td>
</tr>
</table>

</form>
</td>

<td width ="20%"><font color="#FFFFFF">...........................................</font> </td>

</tr>
</table>
TABLE0

$page->footer();
