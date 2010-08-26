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


<td width="70%">
<table width="100%" bgcolor=#FFDD44>
<tr valign=center>
<td width="25%" align=center valign=center> <a href="prediction.pl"> Background </a><br /><br /></td>
<td width="25%"> Output format </td>
<td width="25%"> References </td>
<td width="25%"> Data sets </td>
</tr>
</table>
<br/>
SecreTary predicts whether a signal peptide is present in a protein sequence. It uses another program, tmpred, to look for hydrophobic regions, which are expected within signal peptides. If a hydrophobic region is strongly predicted, its size and position, together with the amino acid composition of the n-terminal end of the protein are the basis  

<font size="+2">
<br/>
<b>Submission </b></font>
<br/>
<font size="+1">Please enter one or more protein sequences in FASTA format.</font>
You may also enter a sequence alone, without identifier, e.g. MDSESESKLISFISQLVSRNNTDSENISCMIQ.
<br/><br/>




<form method="post" action="run_secretary.pl" name="secretary">

<textarea name="sequence" rows="12" cols="100"></textarea> <br/><br/>
 <p>And/or select file:</p>
 <input type="file" name="filename" size="28" />

<table summary="" width="98%">
<tr>
    <td>
    </td>

    <td> <input type="reset" value="Reset" /> </td>

   <td align="right"> <input type="submit" name="submit" value="Submit" /> </td>
</tr>
</table>

</form>

</td>
<td width="5%"></td>


<td width="25%" align=left>
<a name="tools"><strong>Links</strong></a>
<ul>
<li><a href="http://www.cbs.dtu.dk/services/SignalP">SignalP</a></li>
<li><a href="http://www.predisi.de">PrediSi</a></li>
<li><a href="http://rpsp.bioinfo.pl/">RPSP</li>
<li><a href="http://phobius.sbc.su.se/">Phobius</a></li>
<li><a href="http://urgi.versailles.inra.fr/predotar/predotar.html">Predotar</a></li>
</ul>

</td>
</tr>
</table>
TABLE0

$page->footer();
