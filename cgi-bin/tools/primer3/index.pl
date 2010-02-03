#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
  blue_section_html  /;
our $page = CXGN::Page->new( "Primer3", "Adri" );

$page->header();

my $buttons .= "<br />\n";
$buttons .=
  "<input type=\"submit\" name=\"Pick_Primers\" value=\"Pick Primers\" />\n";
$buttons .= "<input type=\"reset\" value=\"Reset Form\" />\n";
$buttons .= "<br /><br />\n";

my $help = "help.pl";

my $intro = <<EOF;

<p>Primer3 picks primers for PCR reactions, considering as criteria:</p>

<ul>
<li>oligonucleotide melting temperature, size, GC content,  and primer-dimer possibilities,</li>
<li>PCR product size,</li>
<li>positional constraints within the source sequence, and</li>
<li>miscellaneous other constraints.</li>
</ul>

<p>All of these criteria are user-specifiable as constraints, and some are specifiable as terms in an objective function that characterizes an optimal primer pair.</p>

<a href="$help#disclaimer">Copyright Notice and Disclaimer</a>

EOF

my $query = <<EOF;

<p>Paste source sequence below (5'->3', string of ACGTNacgtn -- other letters treated as N -- numbers and blanks ignored). FASTA format ok. Please N-out undesirable sequence (vector, ALUs, LINEs, etc.) or use a <a href="$help#PRIMER_MISPRIMING_LIBRARY">Mispriming Library (repeat library):</a></p>

<select name="PRIMER_MISPRIMING_LIBRARY">
<option value="NONE" selected="selected">NONE</option>
<option value="HUMAN">HUMAN</option>
<option value="RODENT_AND_SIMPLE">RODENT_AND_SIMPLE</option>
<option value="RODENT">RODENT</option>
<option value="DROSOPHILA">DROSOPHILA</option>
</select>

<textarea name="SEQUENCE" rows="8" cols="85"></textarea>

<br /><br />

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><input type="checkbox" name="MUST_XLATE_PICK_LEFT" value="1" checked="checked" /></td>
<td width="30%">Pick left primer or use left primer below.</td>
<td><input type="checkbox" name="MUST_XLATE_PICK_HYB_PROBE" value="0" /></td>
<td width="30%">Pick hybridization probe (internal oligo) or use oligo below.</td>
<td><input type="checkbox" name="MUST_XLATE_PICK_RIGHT" value="1" checked="checked" /></td>
<td width="30%">Pick right primer or use right primer below (5'->3' on opposite strand).</td>
<td width="10%"></td>
</tr>

<tr>
<td colspan="2"><input type="text" size="30" name="PRIMER_LEFT_INPUT" value="" /></td>
<td colspan="2"><input type="text" size="30" name="PRIMER_INTERNAL_OLIGO_INPUT" value="" /></td>
<td colspan="2"><input type="text" size="30" name="PRIMER_RIGHT_INPUT" value="" /></td>
<td></td>
</tr>

</table>

$buttons

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#PRIMER_SEQUENCE_ID">Sequence Id:</a></td>
<td><input type="text" name="PRIMER_SEQUENCE_ID" value="" /></td>
<td>A string to identify your output.</td>
</tr>

<tr>
<td><a href="$help#TARGET">Targets:</a></td>
<td><input type="text" name="TARGET" value="" /></td>
<td>E.g. 50,2 requires primers to surround the 2 bases at positions 50 and 51. Or mark the <a href="#PRIMER_SEQUENCE_INPUT">source sequence</a> with [ and ]: e.g. ...ATCT[CCCC]TCAT.. means that primers must flank the central CCCC.</td>
</tr>

<tr>
<td><a href="$help#EXCLUDED_REGION">Excluded Regions:</a></td>
<td><input type="text" name="EXCLUDED_REGION" value="" /></td>
<td>E.g. 401,7 68,3 forbids selection of primers in the 7 bases starting at 401 and the 3 bases at 68. Or mark the <a href="#PRIMER_SEQUENCE_INPUT">source sequence</a> with &lt; and &gt;: e.g. ...ATCT&lt;CCCC&gt;TCAT.. forbids primers in the central CCCC.</td>
</tr>

</table>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td width="20%"><a href="$help#PRIMER_PRODUCT_SIZE_RANGE">Product Size Ranges:</a></td>
<td><input type="text" size="80" name="PRIMER_PRODUCT_SIZE_RANGE" value="150-250 100-300 301-400 401-500 501-600 601-700 701-850 851-1000" /></td>
</tr>

</table>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td width="10%"><a href="$help#PRIMER_NUM_RETURN">Number To Return:</a></td>
<td width="5%"><input type="text" size="4" name="PRIMER_NUM_RETURN" value="5" /></td>
<td width="10%"><a href="$help#PRIMER_MAX_END_STABILITY">Max 3' Stability:</a></td>
<td width="31%"><input type="text" size="4" name="PRIMER_MAX_END_STABILITY" value="9.0" /></td>
</tr>

<tr>
<td> <a href="$help#PRIMER_MAX_MISPRIMING">Max Repeat Mispriming:</a></td>
<td> <input type="text" size="4" name="PRIMER_MAX_MISPRIMING" value="12.00" /></td>
<td> <a href="$help#PRIMER_PAIR_MAX_MISPRIMING">Pair Max Repeat Mispriming:</a></td>
<td> <input type="text" size="4" name="PRIMER_PAIR_MAX_MISPRIMING" value="24.00" /></td>
</tr>

<tr>
<td> <a href="$help#PRIMER_MAX_TEMPLATE_MISPRIMING">Max Repeat Mispriming:</a></td>
<td> <input type="text" size="4" name="PRIMER_MAX_TEMPLATE_MISPRIMING" value="12.00" /></td>
<td> <a href="$help#PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING">Pair Max Repeat Mispriming:</a></td>
<td> <input type="text" size="4" name="PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING" value="24.00" /></td>
</tr>

</table>

$buttons

<h1>General Primer Picking Conditions</h1>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#PRIMER_SIZE">Primer Size</a></td>
<td>Min: <input type="text" size="4" name="PRIMER_MIN_SIZE" value="18" /></td>
<td>Opt: <input type="text" size="4" name="PRIMER_OPT_SIZE" value="20" /></td>
<td>Max: <input type="text" size="4" name="PRIMER_MAX_SIZE" value="27" /></td>
<td></td>
</tr>

<tr>
<td><a href="$help#PRIMER_TM">Primer Tm</a></td>
<td>Min: <input type="text" size="4" name="PRIMER_MIN_TM" value="57.0" /></td>
<td>Opt: <input type="text" size="4" name="PRIMER_OPT_TM" value="60.0" /></td>
<td>Max: <input type="text" size="4" name="PRIMER_MAX_TM" value="63.0" /></td>
<td><a href="$help#PRIMER_MAX_DIFF_TM">Max Tm Difference:</a>
<input type="text" size="4" name="PRIMER_MAX_DIFF_TM" value="100.0" /></td>
</tr>

<tr>
<td><a href="$help#PRIMER_PRODUCT_TM">Product Tm</a></td>
<td>Min: <input type="text" size="4" name="PRIMER_PRODUCT_MIN_TM" value="" /></td>
<td>Opt: <input type="text" size="4" name="PRIMER_PRODUCT_OPT_TM" value="" /></td>
<td>Max: <input type="text" size="4" name="PRIMER_PRODUCT_MAX_TM" value="" /></td>
<td></td>
</tr>

<tr>
<td><a href="$help#PRIMER_GC_PERCENT">Primer GC%</a></td>
<td>Min: <input type="text" size="4" name="PRIMER_MIN_GC" value="20.0" /></td>
<td>Opt: <input type="text" size="4" name="PRIMER_OPT_GC_PERCENT" value="" /></td>
<td>Max: <input type="text" size="4" name="PRIMER_MAX_GC" value="80.0" /></td>
<td></td>
</tr>

</table>


<table summary="" cellpadding="0" cellspacing="0" border="0"><tr>

<td width="50%">

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#PRIMER_SELF_ANY">Max Self Complementarity:</a></td>
<td><input type="text" size="4" name="PRIMER_SELF_ANY" value="8.00" /></td>
</tr>

<tr>
<td><a href="$help#PRIMER_NUM_NS_ACCEPTED">Max #N's:</a></td>
<td><input type="text" size="4" name="PRIMER_NUM_NS_ACCEPTED" value="0" /></td>
</tr>

<tr>
<td><a href="$help#PRIMER_INSIDE_PENALTY">Inside Target Penalty:</a></td>
<td><input type="text" size="4" name="PRIMER_INSIDE_PENALTY" value="" /></td>
</tr>

<tr>
<td><a href="$help#PRIMER_FIRST_BASE_INDEX">First Base Index:</a></td>
<td><input type="text" size="4" name="PRIMER_FIRST_BASE_INDEX" value="1" /></td>
</tr>


<tr>
<td><a href="$help#PRIMER_SALT_CONC">Salt Concentration:</a></td>
<td><input type="text" size="4" name="PRIMER_SALT_CONC" value="50.0" /></td>
</tr>


</table>

</td>

<td width="50%">

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#PRIMER_SELF_END">Max 3' Self Complementarity:</a></td>
<td><input type="text" size="4" name="PRIMER_SELF_END" value="3.00" /></td>
</tr>

<tr>
<td><a href="$help#PRIMER_MAX_POLY_X">Max Poly-X:</a></td>
<td><input type="text" size="4" name="PRIMER_MAX_POLY_X" value="5" /></td>
</tr>

<tr>
<td><a href="$help#PRIMER_OUTSIDE_PENALTY">Outside Target Penalty:</a></td>
<td><input type="text" size="4" name="PRIMER_OUTSIDE_PENALTY" value="0" /></td>
</tr>

<tr>
<td><a href="$help#PRIMER_GC_CLAMP">CG Clamp:</a></td>
<td><input type="text" size="4" name="PRIMER_GC_CLAMP" value="0" /></td>
</tr>

<tr>
<td><a href="$help#PRIMER_DNA_CONC">Annealing Oligo Concentration:</a></td>
<td><input type="text" size="4" name="PRIMER_DNA_CONC" value="50.0" /></td>
</tr>

</table>

</td></tr></table>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><input type="checkbox" name="PRIMER_LIBERAL_BASE" value="1" checked="checked" />
<a href="$help#PRIMER_LIBERAL_BASE">Liberal Base</a></td>				   
<td><input type="checkbox" name="MUST_XLATE_PRINT_INPUT" value="1" />
<a href="$help#SHOW_DEBUGGING">Show Debugging Info</a></td>
<td><input type="checkbox" name="PRIMER_LIB_AMBIGUITY_CODES_CONSENSUS" value="0" checked="checked" />
Do not treat ambiguity codes in libraries as consensus</td>
</tr>

</table>

$buttons

<h1>Other Per-Sequence Inputs</h1>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#INCLUDED_REGION">Included Region:</a></td>
<td><input type="text" name="INCLUDED_REGION" value="" /></td>
<td>E.g. 20,400: only pick primers in the 400 base region starting at position 20. Or use { and } in the <a href="#PRIMER_SEQUENCE_INPUT">source sequence</a> to mark the beginning and end of the included region: e.g. in ATC{TTC...TCT}AT the included region is TTC...TCT.</td>
</tr>

<tr>
<td><a href="$help#PRIMER_START_CODON_POSITION">Start Codon Position:</a></td>
<td><input type="text" name="PRIMER_START_CODON-POSITION" value="" /></td>
</tr>

</table>

<h1><a href="$help#PRIMER_SEQUENCE_QUALITY">Sequence Quality</a></h1>

<textarea rows="2" cols="95" name="PRIMER_SEQUENCE_QUALITY"></textarea>

<table summary="" cellpadding="0" cellspacing="0" border="0">	    

<tr>
<td width="20%"><a href="$help#PRIMER_MIN_QUALITY">Min Sequence Quality:</a></td>
<td width="5%"><input type="text" size="4" name="PRIMER_MIN_QUALITY" value="0" /></td>
<td width="20%"><a href="$help#PRIMER_MIN_END_QUALITY">Min End Sequence Quality:</a></td>
<td width="5%"><input type="text" size="4" name="PRIMER_MIN_END_QUALITY" value="0" /></td>
<td width="20%"><a href="$help#PRIMER_QUALITY_RANGE_MIN">Sequence Quality Range Min:</a></td>
<td width="5%"><input type="text" size="4" name="PRIMER_QUALITY_RANGE_MIN" value="0" /></td>
<td width="20%"><a href="$help#PRIMER_QUALITY_RANGE_MAX">Sequence Quality Range Max:</a></td>
<td width="5%"><input type="text" size="4" name="PRIMER_QUALITY_RANGE_MAX" value="100" /></td>
</tr>

</table>
       
<h1>Objective Function Penalty Weights for Primers</h1>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#generic_penalty_weights">Tm</a></td>
<td>Lt:</td>
<td><input type="text" size="4" name="PRIMER_WT_TM_LT" value="1.0" /></td>
<td>Gt:</td>
<td><input type="text" size="4" name="PRIMER_WT_TM_GT" value="1.0" /></td>
</tr>
    
<tr>
<td><a href="$help#generic_penalty_weights">Size</a></td>
<td>Lt:</td>
<td><input type="text" size="4" name="PRIMER_WT_SIZE_LT" value="1.0" /></td>
<td>Gt:</td>
<td><input type="text" size="4" name="PRIMER_WT_SIZE_GT" value="1.0" /></td>
</tr>
    
<tr>
<td><a href="$help#generic_penalty_weights">GC%</a></td>
<td>Lt:</td>
<td><input type="text" size="4" name="PRIMER_WT_GC_PERCENT_LT" value="0.0" /></td>
<td>Gt:</td>
<td><input type="text" size="4" name="PRIMER_WT_GC_PERCENT_GT" value="0.0" /></td>
</tr>

</table>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#generic_penalty_weights">Self Complementarity</a></td>
<td><input type="text" size="4" name="PRIMER_WT_COMPL_ANY" value="0.0" /></td>
</tr>
		
<tr>
<td><a href="$help#generic_penalty_weights">3' Self Complementarity</a></td>
<td><input type="text" size="4" name="PRIMER_WT_COMPL_END" value="0.0" /></td>
</tr>
		
<tr>
<td><a href="$help#generic_penalty_weights">#N's</a></td>
<td><input type="text" size="4" name="PRIMER_WT_NUM_NS" value="0.0" /></td>
</tr>		

<tr>
<td><a href="$help#generic_penalty_weights">Mispriming</a></td>
<td><input type="text" size="4" name="PRIMER_WT_REP_SIM" value="0.0" /></td>
</tr>

<tr>
<td><a href="$help#generic_penalty_weights">Sequence Quality</a></td>
<td><input type="text" size="4" name="PRIMER_WT_SEQ_QUAL" value="0.0" /></td>
</tr>

<tr>
<td><a href="$help#generic_penalty_weights">End Sequence Quality</a></td>
<td><input type="text" size="4" name="PRIMER_WT_END_QUAL" value="0.0" /></td>
</tr>

<tr>
<td><a href="$help#generic_penalty_weights">Position Penalty</a></td>
<td><input type="text" size="4" name="PRIMER_WT_POS_PENALTY" value="0.0" /></td>
</tr>

<tr>
<td><a href="$help#generic_penalty_weights">End Stability</a></td>
<td><input type="text" size="4" name="PRIMER_WT_END_STABILITY" value="0.0" /></td>
</tr>

</table>

<h1>Objective Function Penalty Weights for Primer Pairs</h1>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#generic_penalty_weights">Product Size</a></td>
<td>Lt:</td>
<td><input type="text" size="4" name="PRIMER_PAIR_WT_PRODUCT_SIZE_LT" value="0.0" /></td>
<td>Gt:</td>
<td><input type="text" size="4" name="PRIMER_PAIR_WT_PRODUCT_SIZE_GT" value="0.0" /></td>
</tr>  
  
<tr>
<td><a href="$help#generic_penalty_weights">Product Tm</a></td>
<td>Lt:</td>
<td><input type="text" size="4" name="PRIMER_PAIR_WT_PRODUCT_TM_LT" value="0.0" /></td>
<td>Gt:</td>
<td><input type="text" size="4" name="PRIMER_PAIR_WT_PRODUCT_TM_GT" value="0.0" /></td>
</tr>

</table>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#generic_penalty_weights">Tm Difference</a></td>
<td><input type="text" size="4" name="PRIMER_PAIR_WT_DIFF_TM" value="0.0" /></td>
</tr>
		
<tr>
<td><a href="$help#generic_penalty_weights">Any Complementarity</a></td>
<td><input type="text" size="4" name="PRIMER_PAIR_WT_COMPL_ANY" value="0.0" /></td>
</tr>	
	
<tr>
<td><a href="$help#generic_penalty_weights">3' Complementarity</a></td>
<td><input type="text" size="4" name="PRIMER_PAIR_WT_COMPL_END" value="0.0" /></td>
</tr>	
	
<tr>
<td><a  href="$help#generic_penalty_weights">Pair Mispriming</a></td>
<td><input type="text" size="4" name="PRIMER_PAIR_WT_REP_SIM" value="0.0" /></td>
</tr>	
	
<tr>
<td><a href="$help#generic_penalty_weights">Primer Penalty Weight</a></td>
<td><input type="text" size="4" name="PRIMER_PAIR_WT_PR_PENALTY" value="1.0" /></td>
</tr>	
	
<tr>
<td><a href="$help#generic_penalty_weights">Hyb Oligo Penalty Weight</a></td>
<td><input type="text" size="4" name="PRIMER_PAIR_WT_IO_PENALTY" value="0.0" /></td>
</tr>
		
</table>

$buttons

<h1><a name="Internal_Oligo_Per-Sequence_Inputs">Hyb Oligo (Internal Oligo) Per-Sequence Inputs</a></h1>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#internal_oligo_generic">Hyb Oligo Excluded Region:</a></td>
<td><input type="text" name="PRIMER_INTERNAL_OLIGO_EXCLUDED_REGION" value="" /></td>
</tr>

</table>

<h1><a name="Internal_Oligo_Global_Parameters">Hyb Oligo (Internal Oligo) General Conditions</a></h1>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#PRIMER_SIZE">Hyb Oligo Size:</a></td>
<td>Min <input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_MIN_SIZE" value="18" /></td>
<td>Opt <input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_OPT_SIZE" value="20" /></td>
<td>Max <input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_MAX_SIZE" value="27" /></td>
</tr>

<tr>
<td><a href="$help#PRIMER_TM">Hyb Oligo Tm:</a></td>
<td>Min <input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_MIN_TM" value="57.0" /></td>
<td>Opt <input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_OPT_TM" value="60.0" /></td>
<td>Max <input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_MAX_TM" value="63.0" /></td>
</tr>

<tr>
<td><a href="$help#PRIMER_GC_PERCENT">Hyb Oligo GC%</a></td>
<td>Min: <input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_MIN_GC" value="20.0" /></td>
<td>Opt: <input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_OPT_GC_PERCENT" value="" /></td>
<td>Max: <input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_MAX_GC" value="80.0" /></td>
</tr>

</table>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#internal_oligo_generic">Hyb Oligo Self Complementarity:</a></td>
<td><input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_SELF_ANY" value="12.00" /></td>
<td><a href="$help#internal_oligo_generic">Hyb Oligo Max 3' Self Complementarity:</a></td>
<td><input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_SELF_END" value="12.00" /></td>
</tr>

<tr>
<td><a href="$help#internal_oligo_generic">Max #Ns:</a></td>
<td><input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_NUM_NS" value="0" /></td>
<td><a href="$help#internal_oligo_generic">Hyb Oligo Max Poly-X:</a></td>
<td><input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_MAX_POLY_X" value="5" /></td>
</tr>

<tr>
<td><a href="$help#internal_oligo_generic">Hyb Oligo Mishyb Library:</a></td>
<td><select name="PRIMER_INTERNAL_OLIGO_MISHYB_LIBRARY">
<option value="none" selected="selected">NONE</option>
<option value="human">HUMAN</option>
<option value="rodent_and_simple">RODENT_AND_SIMPLE</option>
<option value="rodent">RODENT</option>
<option value="drosophila">DROSOPHILA</option>
</select>
</td>
<td><a href="$help#internal_oligo_generic">Hyb Oligo Max Mishyb:</a></td>
<td><input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_MAX_MISHYB" value="12.00" /></td>
</tr>

<tr>
<td><a href="$help#internal_oligo_generic">Hyb Oligo Min Sequence Quality:</a></td>
<td><input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_MIN_QUALITY" value="0" /></td>
</tr>

<tr>
<td><a href="$help#internal_oligo_generic">Hyb Oligo Salt Concentration:</a></td>
<td><input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_SALT_CONC" value="50.0" /></td>
<td><a href="$help#internal_oligo_generic">Hyb Oligo DNA Concentration:</a></td>
<td><input type="text" size="4" name="PRIMER_INTERNAL_OLIGO_DNA_CONC" value="50.0" /></td>
</tr>

</table>

$buttons     
   
<h1>Objective Function Penalty Weights for Hyb Oligos (Internal Oligos)</h1>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr><td>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#generic_penalty_weights">Hyb Oligo Self Complementarity</a></td>
<td><input type="text" size="4" name="PRIMER_IO_WT_COMPL_ANY" value="0.0" /></td>
</tr>
		
<tr>
<td><a href="$help#generic_penalty_weights">Hyb Oligo #N's</a></td>
<td><input type="text" size="4" name="PRIMER_IO_WT_NUM_NS" value="0.0" /></td>
</tr>
		
<tr>
<td><a href="$help#generic_penalty_weights">Hyb Oligo Mishybing</a></td>
<td><input type="text" size="4" name="PRIMER_IO_WT_REP_SIM" value="0.0" /></td>
</tr>
		
<tr>
<td><a href="$help#generic_penalty_weights">Hyb Oligo Sequence Quality</a></td>
<td><input type="text" size="4" name="PRIMER_IO_WT_SEQ_QUAL" value="0.0" /></td>
</tr>
		
</table>

</td>

<td>

<table summary="" cellpadding="0" cellspacing="0" border="0">

<tr>
<td><a href="$help#generic_penalty_weights">Hyb Oligo Tm</a></td>
<td>lt:</td>
<td><input type="text" size="4" name="PRIMER_IO_WT_TM_LT" value="1.0" /></td>
<td>gt:</td>
<td><input type="text" size="4" name="PRIMER_IO_WT_TM_GT" value="1.0" /></td>
</tr>
    
<tr>
<td><a href="$help#generic_penalty_weights">Hyb Oligo Size</a>
</td>
<td>lt:</td>
<td><input type="text" size="4" name="PRIMER_IO_WT_SIZE_LT" value="1.0" /></td>
<td>gt:</td>
<td><input type="text" size="4" name="PRIMER_IO_WT_SIZE_GT" value="1.0" /></td>
</tr>
    
<tr>
<td><a href="$help#generic_penalty_weights">Hyb Oligo GC%</a></td>
<td>lt:</td>
<td><input type="text" size="4" name="PRIMER_IO_WT_GC_PERCENT_LT" value="0.0" /></td>
<td>gt:</td>
<td><input type="text" size="4" name="PRIMER_IO_WT_GC_PERCENT_GT" value="0.0" /></td>
</tr>

</table>

</td></tr>

</table>

$buttons

EOF

print page_title_html("Primer 3");

print "Primer3 is currently unavailable.";

### Unavailable ###
#print blue_section_html( 'Introduction',
#'<table width="100%" cellpadding="5" cellspacing="0" border="0" summary=""><tr><td>'
#      . $intro
#      . '</td></tr></table>' );

#print "<form method=\"post\" action=\"results.pl\">";

#print blue_section_html(
#    'Query Input',
#'<table width="100%" cellpadding="5" cellspacing="0" border="0" summary=""><tr><td>'
#      . $query
#      . '</td></tr></table>'
#);

#print "</form>";

$page->footer();
