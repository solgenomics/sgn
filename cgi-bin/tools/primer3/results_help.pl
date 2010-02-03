#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::VHost;

our $vhost_conf = CXGN::VHost->new();

our $page = CXGN::Page->new( "Primer3 Output Help", "Adri" );

$page->header( 'Primer3 Output Help', 'Primer3 Output Help' );

print <<EOF;

<dl>
<dt><a name="primer_start">start (Start Position)</a></dt>
<dd>The position of the 5' base of the primer. For a Left Primer or Hyb Oligo this position is the position of the leftmost base. For a Right primer it is the position of the <em>rightmost</em> base.</dd>
<dt><a name="primer_len">len (Oligo Length)</a>)</dt>
<dd> The length of the primer or oligo.</dd>
<dt><a name="primer_tm">tm (Melting Temperature)</a>)</dt>
<dd>  The melting temperature of the primer or oligo.</dd>
<dt><a name="primer_gc">gc%</a></dt>
<dd>  The percent of G or C bases in the primer or oligo.</dd>
<dt><a name="primer_any">any (Self Complementarity)</a>)</dt>
<dd> The self-complementarity score of the oligo or primer (taken as a measure of its tendency to anneal to itself or form secondary structure).</dd>
<dt><a name="primer_three">3' (Self Complementarity)</a>)</dt>
<dd>  The 3' self-complementarity of the primer or oligo (taken as a measure of its tendency to form a primer-dimer with itself).</dd>
<dt><a name="primer_repeat">rep (Mispriming or Mishyb Library Similarity)</a>)</dt>
<dd>  The similarity to the specified Mispriming or Mishyb library.</dd>
<dt><a name="primer_seq">seq (Primer Sequence, 5'->3')</a>)</dt>
<dd>  The sequence of the selected primer or oligo, always 5'->3' so the right primer is on the opposite strand from the one supplied in the source input. (The right primer sequence is the sequence you would want synthesized in a primer order.)</dd>
</dl>

EOF

$page->footer();
