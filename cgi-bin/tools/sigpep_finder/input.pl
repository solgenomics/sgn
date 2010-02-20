#!/usr/bin/perl
# User interface for a signal peptide finder using a genentech-generated HMMER model
# This file modified by Evan 9 / 16 / 05

use strict;
use CXGN::Page;

our $page = CXGN::Page->new("Signal Peptide Finder Input Form", "Evan");
$page->header("Signal Peptide Finder",'Signal peptide finder');

print <<HTML1;

<p>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;This method of searching for signal sequences is designed to complement 
SignalP (currently at <a href="http://www.cbs.dtu.dk/services/SignalP/">version 3.0</a>, against which this method was tested), 
and in general has approximately the same success rates. The most important reason we wanted an alternative to SignalP 
is that SignalP has been trained entirely on animal sequences; there are some plant-only protein families that it doesn't 
perform as well on as SGN (being mainly interested in plant families) would prefer.</p>
<p>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;The sequences are HMMSEARCHed with a static <a href="http://hmmer.janelia.org/">HMMER 2.3.2</a> 
model created exclusively from tomato, pepper, tobacco and  <a href="http://www.arabidopsis.org/"><i>Arabidopsis</i></a> 
sequences experimentally determined to have very high probability of being secreted.</p>
<p><b>Enter a single plaintext sequence or a series of FASTA sequences.</b></p>
<!-- <p>Please use the <a href="http://bcf.arl.arizona.edu/resources/docs/iupac.php">IUPAC amino acid alphabet</a>. -->
<p>Please use the <a href="http://embnet.ccg.unam.mx/docs/perl-doc/bioperl.html#amino%20acid%20alphabet">IUPAC amino acid alphabet</a>.
<!-- <p>Please use the <a href="http://doc.bioperl.org/bioperl-live/Bio/Tools/IUPAC.html">IUPAC amino acid alphabet</a>. -->
Exceptions: B, X and Z are not accepted; * (denoting the end of a sequence) is accepted.
</p><p>
Sequences are truncated before processing. It isn't likely we actually consider more than the first 50 symbols.
</p><p>
The more sequences you submit at once, the nicer the score histogram in the output will look.
</p>
<form name="sigseq_form" method="post" action="sigpep_find.pl" enctype="multipart/form-data">
<table summary="" width="100%" border="0" cellpadding="5">
        <tr>
                <td width="40%" valign="top" rowspan="4">
                        <textarea name="sequences" rows="8" cols="44"></textarea>
                        <p>And/or select file:</p>
                        <input type="file" name="filename" size="28" />
								
					</td>
                <td valign="top">
                        <input type="radio" name="display_opt" value="filter" checked="checked" />filter output
					</td>
                <td valign="top">
                        only display output with scores better than the cutoff(s) below
					</td>
        </tr>
        <tr>
                <td valign="top">
                        <br /><input type="radio" name="display_opt" value="color" />show all output, use colors
					</td>
                <td valign="top">
                        display all output scores, good ones in green, bad in red, according to the cutoff(s) below
					</td>
        </tr>
        <tr>
                <td valign="top">
                        <input type="checkbox" name="use_eval_cutoff" checked="checked" />use E-value cutoff:
                        <br />&nbsp;&nbsp;&nbsp;<input type="text" name="eval_cutoff" size="7" maxlength="6" value="2" />
					</td>
                <td valign="top">
                        set a threshold for displaying/not displaying output or for displaying in red vs. green
					</td>
        </tr>
        <tr>
                <td valign="top">
                        <input type="checkbox" name="use_bval_cutoff" checked="checked" />use bit-value cutoff:
                        <br />&nbsp;&nbsp;&nbsp;<input type="text" name="bval_cutoff" size="7" maxlength="6" value="0" />
					</td>
                <td valign="top">
                        another display threshold (each threshold is a possible restriction on output)
					</td>
        </tr>
</table>
<input type="reset" value="Reset" />
&nbsp;&nbsp;<input type="submit" value="Submit" />
</form>


HTML1

$page->footer();
