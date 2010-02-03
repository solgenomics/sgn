#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::VHost;

our $vhost_conf = CXGN::VHost->new();

my $documents = "/documents/primer3";

our $page = CXGN::Page->new( "Primer3 Input Help", "Adri" );

$page->header( 'Primer3 Input Help', 'Primer3 Input Help' );

print <<EOF;

<h1><a name="cautions">Cautions</a></h1>

<p>Some of the most important issues in primer picking can be
addressed only before using Primer3.  These are sequence quality
(including making sure the sequence is not vector and not
chimeric) and avoiding repetitive elements.</p>

<p>Techniques for avoiding problems include a thorough understanding
of possible vector contaminants and cloning artifacts coupled
with database searches using blast, fasta, or other similarity
searching program to screen for vector contaminants and possible
repeats.  Repbase (J. Jurka, A.F.A. Smit, C. Pethiyagoda, and
others, 1995-1996)
<a href="ftp://ftp.ncbi.nih.gov/repository/repbase">ftp://ftp.ncbi.nih.gov/repository/repbase</a>)
is an excellent source of repeat sequences and pointers to the
literature.  Primer3 now allows you to screen candidate oligos
against a Mispriming Library (or a Mishyb Library in the case
of internal oligos).</p>

<p>Sequence quality can be controlled by manual trace viewing and
quality clipping or automatic quality clipping programs.  Low-
quality bases should be changed to N's or can be made part of
Excluded Regions. The beginning of a sequencing read is often
problematic because of primer peaks, and the end of the read
often contains many low-quality or even meaningless called bases.
Therefore when picking primers from single-pass sequence it is
often best to use the Included Region parameter to ensure that
Primer3 chooses primers in the high quality region of the read.  In addition, Primer3 takes as input a <a href="#SEQUENCE_QUALITY">Sequence Quality</a> list for
use with those base calling programs such as Phred that output this information.</p>

<dl>

<dt><a name="SEQUENCE"><strong>Source Sequence</strong></a></dt>

<dd>The sequence from which to select primers or hybridization oligos.</dd>

<dt><a name="PRIMER_SEQUENCE_ID"><strong>Sequence Id</strong></a></dt>

<dd>An identifier that is reproduced in the output to enable you to identify the chosen primers.</dd>

<dt><a name="TARGET"><strong>Targets</strong></a></dt>

<dd>If one or more Targets is specified then a legal primer pair must
flank at least one of them.  A Target might be a simple sequence
repeat site (for example a CA repeat) or a single-base-pair
polymorphism.  The value should be a space-separated list of

<pre><tt><i>start</i></tt>,<tt><i>length</i></tt></pre>

pairs where <tt><i>start</i></tt> is the index of the first base of a Target, and <tt><i>length</i></tt> is its length.</dd>

<dt><a name="EXCLUDED_REGION"><strong>Excluded Regions</strong></a></dt>
<dd>Primer oligos may not overlap any region specified in this tag.
The associated value must be a space-separated list of

<pre><tt><i>start</i></tt>,<tt><i>length</i></tt></pre>

pairs where <tt><i>start</i></tt> is the index of the first base of
the excluded region, and <tt><i>length</i></tt> is its length.  This tag is
useful for tasks such as excluding regions of low sequence
quality or for excluding regions containing repetitive elements
such as ALUs or LINEs.</dd>


<dt><a name="PRIMER_PRODUCT_SIZE_RANGE"><strong>Product Size Range</strong></a></dt>

<dd>A list of product size ranges, for example <pre>150-250 100-300 301-400</pre>
Primer3 first tries to pick
primers in the first range.  If that is not possible,
it goes to the next range and tries again.  It continues in this
way until it has either picked all necessary primers or until there are no
more ranges.  For technical reasons this option makes much lighter
computational demands than the Product Size option.</dd>

<dt><a name="PRIMER_PRODUCT_SIZE"><strong>Product Size</strong></a></dt>

<dd>Minimum, Optimum, and Maximum lengths (in bases) of the PCR product.
Primer3 will not generate primers with products shorter than Min
or longer than Max, and with default arguments Primer3 will
attempt to pick primers producing products close to the Optimum
length.</dd>

<dt><a name="PRIMER_NUM_RETURN"><strong>Number To Return</strong></a></dt>

<dd>The maximum number of primer pairs to return.  Primer pairs
returned are sorted by their &quot;quality&quot;, in other words by the
value of the objective function (where a lower number indicates a
better primer pair).  Caution: setting this parameter to a large
value will increase running time.</dd>

<dt><a name="PRIMER_MAX_END_STABILITY"><strong>Max 3' Stability</strong></a></dt>

<dd>The maximum stability for the five 3' bases of a left or right
primer.  Bigger numbers mean more stable 3' ends.  The value is
the maximum delta G for duplex disruption for the five 3' bases
as calculated using the nearest neighbor parameters published in
Breslauer, Frank, Bloeker and Marky, Proc. Natl. Acad. Sci. USA,
vol 83, pp 3746-3750.  Rychlik recommends a maximum value of 9
(Wojciech Rychlik, &quot;Selection of Primers for Polymerase Chain
Reaction&quot; in BA White, Ed., &quot;Methods in Molecular Biology,
Vol. 15: PCR Protocols: Current Methods and Applications&quot;, 1993,
pp 31-40, Humana Press, Totowa NJ).</dd>

<dt><a name="PRIMER_MAX_MISPRIMING"><strong>Max Mispriming</strong></a></dt>

<dd>The maximum allowed weighted similarity with any sequence in
Mispriming Library. Default is 12.</dd>
    
<dt><a name="PRIMER_MAX_TEMPLATE_MISPRIMING"><strong>Max Template Mispriming</strong></a></dt>

<dd>The maximum allowed similarity to ectopic sites in the sequence from which you are designing the primers. The scoring system is the same as used for Max Mispriming, except that an ambiguity code is never treated as a consensus.</dd>

<dt><a name="PRIMER_PAIR_MAX_MISPRIMING"><strong>Pair Max Mispriming</strong></a></dt>

<dd>The maximum allowed sum of similarities of a primer pair
(one similarity for each primer) with any single sequence in
Mispriming Library. Default is 24. Library sequence weights are not used in computing the sum of similarities.</dd>

<dt><a name="PRIMER_PAIR_MAX_TEMPLATE_MISPRIMING"><strong>Pair Max Template Mispriming</strong></a></dt>
    
<dd>The maximum allowed summed similarity of both primers to ectopic sites in the sequence from which you are designing the primers. The scoring system is the same as used for Max Mispriming, except that an ambiguity code is never treated as a consensus.</dd>

<dt><a name="PRIMER_SIZE"><strong>Primer Size</strong></a></dt>

<dd>Minimum, Optimum, and Maximum lengths (in bases) of a primer oligo.
Primer3 will not pick primers shorter than Min or longer than
Max, and with default arguments will attempt to pick primers
close with size close to Opt.  Min cannot be smaller than 1.
Max cannot be larger than 36.
(This limit is governed by maximum oligo size for which
melting-temperature calculations are valid.)
Min cannot be greater than Max.</dd>

<dt><a name="PRIMER_TM"><strong>Primer T<sub>m</sub></strong></a></dt>

<dd><p>Minimum, Optimum, and Maximum melting temperatures (Celsius)
for a primer oligo. Primer3 will not pick oligos with temperatures
smaller than Min or larger than Max, and with default conditions
will try to pick primers with melting temperatures close to Opt.</p>
<p>Primer3 uses the oligo melting temperature formula given in
Rychlik, Spencer and Rhoads, Nucleic Acids Research, vol 18, num
21, pp 6409-6412 and Breslauer, Frank, Bloeker and Marky,
Proc. Natl. Acad. Sci. USA, vol 83, pp 3746-3750.  Please refer
to the former paper for background discussion.</p></dd>

<dt><a name="PRIMER_MAX_DIFF_TM"><strong>Maximum T<sub>m</sub> Difference</strong></a></dt>

<dd>Maximum acceptable (unsigned) difference between the melting
temperatures of the left and right primers.</dd>

<dt><a name="PRIMER_PRODUCT_TM"><strong>Product T<sub>m</sub></strong></a></dt>

<dd>The minimum, optimum, and maximum melting temperature of the
amplicon.  Primer3 will not pick a product with melting
temperature less than min or greater than max. If Opt is supplied
and the <a href="#PAIR_WT_PRODUCT_TM">Penalty Weights for Product
Size</a> are non-0 Primer3 will attempt to pick an amplicon with
melting temperature close to Opt.</dd>

<dd>The maximum allowed melting temperature of the amplicon.  Primer3
calculates product T<sub>m</sub> calculated using the formula from Bolton
and McCarthy, PNAS 84:1390 (1962) as presented in Sambrook,
Fritsch and Maniatis, Molecular Cloning, p 11.46 (1989, CSHL
Press).

<blockquote>
   T<sub>m</sub> = 81.5 + 16.6(log<sub>10</sub>([Na+])) + .41*(%GC) - 600/length,
</blockquote>

where [Na+] is the molar sodium concentration, (%GC) is the
percent of Gs and Cs in the sequence, and length is the length of
the sequence.</dd>

<dd>A similar formula is used by the prime primer selection program
in GCG (<a href="http://www.gcg.com">http://www.gcg.com</a>),
which instead uses 675.0 / length in
the last term (after F. Baldino, Jr, M.-F. Chesselet, and M.E.
Lewis, Methods in Enzymology 168:766 (1989) eqn (1) on page 766
without the mismatch and formamide terms).  The formulas here and
in Baldino et al. assume Na+ rather than K+.  According to
J.G. Wetmur, Critical Reviews in BioChem. and Mol. Bio. 26:227
(1991) 50 mM K+ should be equivalent in these formulae to .2 M
Na+.  Primer3 uses the same salt concentration value for
calculating both the primer melting temperature and the oligo
melting temperature.  If you are planning to use the PCR product
for hybridization later this behavior will not give you the T<sub>m</sub> 
under hybridization conditions.</dd>

<dt><a name="PRIMER_GC_PERCENT"><strong>Primer GC%</strong></a></dt>

<dd>Minimum, Optimum, and Maximum percentage of Gs and Cs in any primer.</dd>

<dt><a name="PRIMER_SELF_ANY"><strong>Max Complementarity</strong></a></dt>

<dd>The maximum allowable local alignment score when testing a single
primer for (local) self-complementarity and the maximum allowable
local alignment score when testing for complementarity between
left and right primers.  Local self-complementarity is taken to
predict the tendency of primers to anneal to each other without
necessarily causing self-priming in the PCR.  The scoring system
gives 1.00 for complementary bases, -0.25 for a match of any base
(or N) with an N, -1.00 for a mismatch, and -2.00 for a gap.
Only single-base-pair gaps are allowed.  For example, the
alignment

<pre>
5' ATCGNA 3'
   || | |
3' TA-CGT 5'
</pre>

is allowed (and yields a score of 1.75), but the alignment

<pre>
5' ATCCGNA 3'
   ||  | |
3' TA--CGT 5'
</pre>

is not considered.  Scores are non-negative, and a score of 0.00
indicates that there is no reasonable local alignment between two
oligos.</dd>

<dt><a name="PRIMER_SELF_END"><strong>Max 3' Complementarity</strong></a></dt>

<dd>The maximum allowable 3'-anchored global alignment score when
testing a single primer for self-complementarity, and the maximum
allowable 3'-anchored global alignment score when testing for
complementarity between left and right primers.  The 3'-anchored
global alignment score is taken to predict the likelihood of
PCR-priming primer-dimers, for example

<pre>
5' ATGCCCTAGCTTCCGGATG 3'
             ||| |||||
          3' AAGTCCTACATTTAGCCTAGT 5'
</pre>

or

<pre>
5` AGGCTATGGGCCTCGCGA 3'
               ||||||
            3' AGCGCTCCGGGTATCGGA 5'
</pre>

The scoring system is as for the Max Complementarity
argument.  In the examples above the scores are 7.00 and 6.00
respectively.  Scores are non-negative, and a score of 0.00
indicates that there is no reasonable 3'-anchored global
alignment between two oligos.  In order to estimate 3'-anchored
global alignments for candidate primers and primer pairs, Primer
assumes that the sequence from which to choose primers is
presented 5'->3'.  It is nonsensical to provide a larger value
for this parameter than for the Maximum (local) Complementarity
parameter because the score of a local alignment will always be at
least as great as the score of a global alignment.</dd>

<dt><a name="PRIMER_MAX_POLY_X"><strong>Max Poly-X</strong></a></dt>

<dd>The maximum allowable length of a mononucleotide repeat,
for example AAAAAA.</dd>

<dt><a name="INCLUDED_REGION"><strong>Included Region</strong></a></dt>

<dd>A sub-region of the given sequence in which to pick primers.  For
example, often the first dozen or so bases of a sequence are
vector, and should be excluded from consideration. The value for
this parameter has the form

<pre>
<tt><i>start</i></tt>,<tt><i>length</i></tt>
</pre>

where <tt><i>start</i></tt> is the index of the first base to consider,
and <tt><i>length</i></tt> is the number of subsequent bases in the
primer-picking region.</dd>

<dt><a name="PRIMER_START_CODON_POSITION"><strong>Start Codon Position</strong></a></dt>

<dd>This parameter should be considered EXPERIMENTAL at this point.
Please check the output carefully; some erroneous inputs might
cause an error in Primer3. Index of the first base of a start codon.  This parameter allows
Primer3 to select primer pairs to create in-frame amplicons
e.g. to create a template for a fusion protein.  Primer3 will
attempt to select an in-frame left primer, ideally starting at or
to the left of the start codon, or to the right if necessary.
Negative values of this parameter are legal if the actual start
codon is to the left of available sequence. If this parameter is
non-negative Primer3 signals an error if the codon at the
position specified by this parameter is not an ATG.  A value less
than or equal to -10^6 indicates that Primer3 should ignore this
parameter. Primer3 selects the position of the right primer by scanning
right from the left primer for a stop codon.  Ideally the right
primer will end at or after the stop codon.</dd>

<dt><a name="PRIMER_MISPRIMING_LIBRARY"><strong>Mispriming Library</strong></a></dt>

<dd>This selection indicates what mispriming library (if any)
Primer3 should use to screen for interspersed repeats or
for other sequence to avoid as a location for primers.
The human and rodent libraries on the web page are adapted from
Repbase (J. Jurka, A.F.A. Smit, C. Pethiyagoda, et al.,
1995-1996)
<a href="ftp://ftp.ncbi.nih.gov/repository/repbase">ftp://ftp.ncbi.nih.gov/repository/repbase</a>).
The
human library is humrep.ref concatenated with simple.ref,
translated to FASTA format.  There are two rodent libraries.
One is rodrep.ref translated to FASTA format, and the other is
rodrep.ref concatenated with simple.ref, translated to
FASTA format.</dd>

<dd>The <i>Drosophila</i> library is the concatenation of two libraries
from the <a href="http://www.fruitfly.org">Berkeley Drosophila Genome Project</a>:</dd>

<dd>
<ol>
<li>A library of transposable elements
<a href="http://genomebiology.com/2002/3/12/research/0084">
<i>The transposable elements of the Drosophila melanogaster euchromatin - a genomics perspective</i>
J.S. Kaminker, C.M. Bergman, B. Kronmiller, J. Carlson, R. Svirskas, S. Patel, E. Frise, D.A. Wheeler, S.E. Lewis, G.M. Rubin, M. Ashburner and S.E. Celniker
Genome Biology (2002) 3(12):research0084.1-0084.20</a>, 
<a href="http://www.fruitfly.org/p_disrupt/datasets/ASHBURNER/D_mel_transposon_sequence_set.fasta">
http://www.fruitfly.org/p_disrupt/datasets/ASHBURNER/D_mel_transposon_sequence_set.fasta</a></li>

<li>A library of repetitive DNA sequences <a href="http://www.fruitfly.org/sequence/sequence_db/na_re.dros">
http://www.fruitfly.org/sequence/sequence_db/na_re.dros</a>.</li>
</ol></dd>

<dd>Both were downloaded 6/23/04.</dd>

<dd>The contents of the libraries can be viewed at the following links:</dd>

<dd>
<ul>
<li> <a href="$documents/human.txt">HUMAN</a> (contains microsatellites)</li>
<li> <a href="$documents/rodent_and_simple.txt">RODENT_AND_SIMPLE</a> (contains microsatellites)</li>
<li> <a href="$documents/rodent.txt">RODENT</a> (does not contain microsatellites)</li>
<li> <a href="$documents/drosophila.txt">DROSOPHILA</a></li>
</ul>
</dd>

<dt><a name="PRIMER_GC_CLAMP"><strong>CG Clamp</strong></a></dt>

<dd>Require the specified number of consecutive Gs and Cs at the 3'
end of both the left and right primer.  (This parameter has no
effect on the hybridization oligo if one is requested.)</dd>

<dt><a name="PRIMER_SALT_CONC"><strong>Salt Concentration</strong></a></dt>

<dd>The millimolar concentration of salt (usually KCl) in the PCR.
Primer3 uses this argument to calculate oligo melting
temperatures.</dd>

<dt><a name="PRIMER_DNA_CONC"><strong>Annealing Oligo Concentration</strong></a></dt>

<dd>The nanomolar concentration of annealing oligos in the PCR.
Primer3 uses this argument to calculate oligo melting
temperatures.  The default (50nM) works well with the standard
protocol used at the Whitehead/MIT Center for Genome
Research--0.5 microliters of 20 micromolar concentration for each
primer oligo in a 20 microliter reaction with 10 nanograms
template, 0.025 units/microliter Taq polymerase in 0.1 mM each
dNTP, 1.5mM MgCl2, 50mM KCl, 10mM Tris-HCL (pH 9.3) using 35
cycles with an annealing temperature of 56 degrees Celsius.  This
parameter corresponds to 'c' in Rychlik, Spencer and Rhoads'
equation (ii) (Nucleic Acids Research, vol 18, num 21) where a
suitable value (for a lower initial concentration of template) is
&quot;empirically determined&quot;.  The value of this parameter is less
than the actual concentration of oligos in the reaction because
it is the concentration of annealing oligos, which in turn
depends on the amount of template (including PCR product) in a
given cycle.  This concentration increases a great deal during a
PCR; fortunately PCR seems quite robust for a variety of oligo
melting temperatures.</dd>

<dt><a name="PRIMER_NUM_NS_ACCEPTED"><strong>Max Ns Accepted</strong></a></dt>

<dd>Maximum number of unknown bases (N) allowable in any primer.</dd>

<dt><a name="PRIMER_LIBERAL_BASE"><strong>Liberal Base</strong></a></dt>

<dd>This parameter provides a quick-and-dirty way to get Primer3 to
accept IUB / IUPAC codes for ambiguous bases (i.e. by changing
all unrecognized bases to N).  If you wish to include an
ambiguous base in an oligo, you must set
<a href="#PRIMER_NUM_NS_ACCEPTED">Max Ns Accepted</a> to a
non-0 value.  Perhaps '-' and '* ' should be squeezed out rather than changed
to 'N', but currently they simply get converted to N's.  The authors
invite user comments.</dd>

<dt><a name="PRIMER_FIRST_BASE_INDEX"><strong>First Base Index</strong></a></dt>

<dd>The index of the first base in the input
sequence.  For input and output using 1-based indexing (such as
that used in GenBank and to which many users are accustomed) set
this parameter to 1.  For input and output using 0-based indexing
set this parameter to 0.  (This parameter also affects the
indexes in the contents of the files produced when the primer
file flag is set.)
In the WWW interface this parameter defaults to 1.</dd>

<dt><a name="PRIMER_INSIDE_PENALTY"><strong>Inside Target Penalty</strong></a></dt>

<dd> Non-default values valid only for sequences
with 0 or 1 target regions.  If the primer is part of a pair that
spans a target and overlaps the target, then multiply this value
times the number of nucleotide positions by which the primer
overlaps the (unique) target to get the 'position penalty'.  The
effect of this parameter is to allow Primer3 to include overlap
with the target as a term in the objective function.</dd>

<dt><a name="PRIMER_OUTSIDE_PENALTY"><strong>Outside Target Penalty</strong></a></dt>

<dd>  Non-default values valid only for sequences
with 0 or 1 target regions.  If the primer is part of a pair that
spans a target and does not overlap the target, then multiply
this value times the number of nucleotide positions from the 3'
end to the (unique) target to get the 'position penalty'.
The effect of this parameter is to allow Primer3 to include
nearness to the target as a term in the objective function.</dd>

<dt><a name="SHOW_DEBUGGING"><strong>Show Debuging Info</strong></a></dt>

<dd>Include the input to primer3_core as part of the output.</dd>

</dl>

<h1><a name="SEQUENCE_QUALITY">Sequence Quality</a></h1>

<dl>

<dt><a name="PRIMER_SEQUENCE_QUALITY"><strong>Sequence Quality</strong></a></dt>

<dd>A list of space separated integers. There must be exactly one
integer for each base in the Source Sequence if this argument is non-empty.
High numbers indicate high confidence in the base call at that
position and low numbers indicate low confidence in the base
call at that position.</dd>

<dt><a name="PRIMER_MIN_QUALITY"><strong>Min Sequence Quality</strong></a></dt>

<dd>The minimum sequence quality (as specified by
Sequence Quality) allowed within a primer.</dd>

<dt><a name="PRIMER_MIN_END_QUALITY"><strong>Min 3' Sequence Quality</strong></a></dt>

<dd>The minimum sequence quality (as specified by
Sequence Quality) allowed within the 3' pentamer of a primer.</dd>

<dt><a name="PRIMER_QUALITY_RANGE_MIN"><strong>Sequence Quality Range Min</strong></a></dt>

<dd>The minimum legal sequence quality (used for interpreting
Min Sequence Quality and Min 3' Sequence Quality).</dd>

<dt><a name="PRIMER_QUALITY_RANGE_MAX"><strong>Sequence Quality Range Max</strong></a></dt>

<dd>The maximum legal sequence quality (used for interpreting
Min Sequence Quality and Min 3' Sequence Quality).</dd>

</dl>

<h1><a name="generic_penalty_weights">Penalty Weights</a></h1>

<p>This section describes "penalty weights", which allow
the user to modify the criteria that Primer3 uses
to select the "best" primers.  There are two classes
of weights: for some parameters there is a 'Lt' (less
than) and a 'Gt' (greater than) weight.  These
are the weights that Primer3 uses when the value
is less or greater than (respectively) the specified optimum.
The following parameters have both 'Lt' and 'Gt' weights:</p>

<ul>
<li> Product Size</li>
<li> Primer Size</li>
<li> Primer T<sub>m</sub></li>
<li> Product T<sub>m</sub></li>
<li> Primer GC%</li>
<li> Hyb Oligo Size</li>
<li> Hyb Oligo T<sub>m</sub></li>
<li> Hyb Oligo GC%</li>
</ul>

<p>The <a href="#PRIMER_INSIDE_PENALTY">Inside Target Penalty</a>
and <a href="#PRIMER_OUTSIDE_PENALTY">Outside Target Penalty</a>
are similar, except that since they relate
to position they do not lend them selves to the
'Lt' and 'Gt' nomenclature.</p><p>
For the remaining parameters the optimum is understood
and the actual value can only vary in one direction
from the optimum:</p>

<ul>
<li>Primer Self Complementarity</li>
<li>Primer 3' Self Complementarity</li>
<li>Primer #N's</li>
<li>Primer Mispriming Similarity</li>
<li>Primer Sequence Quality</li>
<li>Primer 3' Sequence Quality</li>
<li>Primer 3' Stability</li>
<li>Hyb Oligo Self Complementarity</li>
<li>Hyb Oligo 3' Self Complementarity</li>
<li>Hyb Oligo Mispriming Similarity</li>
<li>Hyb Oligo Sequence Quality</li>
<li>Hyb Oligo 3' Sequence Quality</li>
</ul>

<p>The following are weights are treated specially:</p>

<dl>
<dt>Position Penalty Weight</dt>
<dd>Determines the overall weight of the position penalty
    in calculating the penalty for a primer.</dd>
<dt>Primer Weight</dt>
<dd>Determines the weight of the 2 primer penalties in
    calculating the primer pair penalty.</dd>
<dt>Hyb Oligo Weight</dt>
<dd>Determines the weight of the hyb oligo penalty in
    calculating the penalty of a primer pair plus hyb
    oligo.</dd>
</dl>

<p>The following govern the weight given to various 
parameters of primer pairs (or primer pairs plus
hyb oligo).</p>

<ul>
<li>T<sub>m</sub> difference</li>
<li>Primer-Primer Complementarity</li>
<li>Primer-Primer 3' Complementarity</li>
<li>Primer Pair Mispriming Similarity</li>
</ul>

<h1><a name="internal_oligo_generic">Hyb Oligos (Internal Oligos)</a></h1>

<p>Parameters governing choice of internal
oligos are analogous to the parameters governing
choice of primer pairs.
The exception is Max 3' Complementarity
which is meaningless when applied
to internal oligos used for hybridization-based detection, since
primer-dimer will not occur.  We recommend that Max 3' Complementarity
be set at least as high as Max Complementarity.</p>

<h1><a name="disclaimer">Copyright Notice and Disclaimer</a></h1>
 
<p>Copyright (c) 1996,1997,1998,1999,2000,2001,2004
        Whitehead Institute for Biomedical Research. All rights reserved.</p>
<p>Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:</p>
<ol>
<li>Redistributions must reproduce the above copyright notice, this
list of conditions and the following disclaimer in the  documentation
and/or other materials provided with the distribution.  Redistributions of
source code must also reproduce this information in the source code itself.</li>
<li>If the program is modified, redistributions must include a notice
(in the same places as above) indicating that the redistributed program is
not identical to the version distributed by Whitehead Institute.</li>
<li>All advertising materials mentioning features or use of this
software  must display the following acknowledgment:
<blockquote><i>
        This product includes software developed by the
        Whitehead Institute for Biomedical Research.
</i></blockquote></li>
<li>The name of the Whitehead Institute may not be used to endorse or
promote products derived from this software without specific prior written
permission.</li>
</ol>

<p>We also request that use of this software be cited in publications as</p>

<blockquote>
Steve Rozen and Helen J. Skaletsky (2000)
Primer3 on the WWW for general users and for biologist programmers.
In: Krawetz S, Misener S (eds)
<i>Bioinformatics Methods and Protocols: Methods in Molecular Biology.</i>
Humana Press, Totowa, NJ, pp 365-386<br />
<a href="http://fokker.wi.mit.edu/primer3/">
Source code available at http://fokker.wi.mit.edu/primer3/.
</a>
</blockquote>

<p>THIS SOFTWARE IS PROVIDED BY THE WHITEHEAD INSTITUTE ``AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE WHITEHEAD INSTITUTE BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.</p>

<h1>Acknowledgments</h1>

<p>The development of Primer3 and the Primer3
web site was funded by
<a href="http://www.hhmi.org/">Howard Hughes Medical Institute</a>
and by the 
<a href="http://www.nih.gov/">National Institutes of Health,</a>
<a href="http://www.nhgri.nih.gov/">
National Human Genome Research Institute.</a>
under grants R01-HG00257
(to David C. Page) and P50-HG00098 (to Eric S. Lander).</p>
<p>We gratefully acknowledge the support of
Digital Equipment Corporation,
which provided the Alphas which were used for much
of the development of Primer3, and of 
Centerline Software, Inc.,
whose TestCenter memory-error, -leak, and test-coverage checker
we use regularly to discover and correct otherwise latent
errors in Primer3.</p>

<hr />

<p>Web software provided by
<em><a href="http://jura.wi.mit.edu/rozen">Steve Rozen</a></em>
and <a href="http://wi.mit.edu">
<em>Whitehead Institute for Biomedical Research.</em></a></p>

EOF

$page->footer();
