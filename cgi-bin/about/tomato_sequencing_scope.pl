use strict;
use warnings;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html/;

my $page = CXGN::Page->new('tomato sequencing scope','Robert Buels');

$page->header(('Tomato Sequencing Scope and Completion Criteria') x 2);

print <<EOH;
<p>This page explains what parts of the tomato genome will be sequenced by the <a href="/about/tomato_project_overview.pl">International Tomato Sequencing Project</a>, and when the project will be considered complete.</p>

<div style="text-align: right; margin-bottom: 1em"><b>Download sequencing scope presentation:</b> <a href="/documents/about/tomato_sequencing_scope.ppt">[ppt]</a></div>
EOH

print info_section_html( title => '1. Sequencing scope',
			 contents =>
			 info_section_html( title => '1.1 Estimate of euchromatin size and number of BACs to sequence',
					    is_subsection => 1,
					    contents => <<EOH)
<p>We have developed estimates of the physical distance to be covered in sequencing the euchromatin gene space of tomato centromeric arms.  While more accurate estimates will develop as the project proceeds and more sequence is generated, we note that the current estimates are similar to each other.</p>

<dl>
<dt>A. Cytologically Based Measurement of Euchromatin Content</dt>

<dd>We previously determined the amount of DNA in euchromatin and
    heterochromatin of tomato chromosomes (Peterson et al. 1996).
    First, tomato pachytene chromosomes were spread on glass slides
    using a technique that did not stretch (deform) the chromosomes.
    We stained the chromosomes by the Feulgen technique that has been
    proven to be a reliable, quantitative stain for DNA (see Price
    1988). Relative density (absorbance) of Feulgen stained
    euchromatin and heterochromatin was determined in ten different
    spreads.  Using twenty unstretched tomato pachytene chromosomes,
    the average width of the chromosomes in euchromatin was determined
    from fifty separate measurements, and the average width of the
    chromosomes in heterochromatin was determined from fifty
    additional measurements.  Transverse measurements for diameter
    were made only in relatively straight parts of chromosomes.
    Lengths of pachytene chromosomes were taken from Sherman and Stack
    (1992) who carefully measured tomato pachytene chromosome lengths,
    arm ratios, and fractions of arms in euchromatin and
    heterochromatin on electron micrographs. This information was used
    to calculate the total fraction of the genome in euchromatin and
    heterochromatin.
    <center>
    <table>
    <tr><td></td><th>Heterochromatin</th><th>Euchromatin</th></tr>
    <tr>
        <td align="right">Relative chromosome length</td>
        <td align="right">0.36</td>
        <td align="right">0.64</td>
    </tr>
    <tr>
	<td align="right">Relative bivalent diameter</td>
        <td align="right">&times;  1.23 <hr style="padding: 0; margin: 0 0 0 3em; border: 1px solid black" /></td>
	<td align="right">&times;  1.00 <hr style="padding: 0; margin: 0 0 0 3em; border: 1px solid black" /></td>
    </tr>
    <tr>
        <td align="right">Relative area</td>
        <td align="right">0.44</td>
        <td align="right">0.64</td>
    </tr>
    <tr>
        <td align="right">Relative optical density</td>
        <td align="right">&times;  4.78 <hr style="padding: 0; margin: 0 0 0 3em; border: 1px solid black" /></td>
        <td align="right">&times;  1.00 <hr style="padding: 0; margin: 0 0 0 3em; border: 1px solid black" /></td>
    </tr>
    <tr>
        <td align="right">Relative OD X relative area</td>
        <td align="right">2.10</td>
        <td align="right">0.64</td>
    </tr>
    <tr>
        <td align="right">Total OD X area</td>
        <td align="right">&divide; 2.74 <hr style="padding: 0; margin: 0 0 0 3em; border: 1px solid black" /></td>
        <td align="right">&divide; 2.74 <hr style="padding: 0; margin: 0 0 0 3em; border: 1px solid black" /></td>
    </tr>
    <tr>
        <td align="right">Fraction of genome</td>
        <td align="right">0.77</td>
        <td align="right">0.23</td>
    </tr>
    </table>
    </center>

    Estimates of the absolute size (1C amount) of the tomato genome
    are in general agreement at approximately 95 pg of DNA, e.g.,
    Michaelson et al. (1991).  Thus, the amount of DNA in euchromatin
    in one tomato genome is (0.23 x 0.95 pg =) 0.22 pg.  Converting
    the DNA amount in euchromatin to base pairs (Bennett and Smith
    1976) there are [0.22 pg x (965 x106 pb/pg) =] 2.12 x 108 bp (212
    Mb) of DNA in the euchromatin of one tomato genome (= 1C amount),
    and converting the DNA amount in heterochromatin to base pairs
     [0.73 pg x (965 x106 pb/pg) =], there are 7.05 x 108 bp (705 Mb)
    of DNA in the heterochromatin of one tomato genome.
</dd>
<dt>B. Estimating Euchromatin Arm Size Based on Available Genome and EST Sequence</dt>
<dd>
   As of the summer of 2006 a total of 15.5 Mb of non-overlapping
   tomato genomic sequence had been submitted to SGN by the US team
   and our international sequencing partners.  A test set of high
   quality tomato gene sequences was created by combining 1) all
   published tomato gene sequences in GENBANK, 2) 2898 redundantly
   sequenced full-length tomato cDNAs available through TIGR, and 3)
   6742 tomato contigs containing five or more overlapping EST
   sequences.  8,097 high quality unigene sequences remained after
   correcting for redundancy.  This set of tomato unigenes was then
   searched against the available tomato genome sequence with
   stringency criteria of 90% or greater ty and % coverage.  456 of
   8,097 unigenes were identified in the genome sequence.  Assuming
   this gene set is representative of the gene space in terms of
   localization throughout the tomato genome, we estimate that
   456/8,097 = 5.6% of the gene space has been covered.  Correcting
   for the percentage of gene space present in the euchromatin arms
   (85%) we can calculate that 5.6/0.85 = 6.6% of the target gene
   space has been covered.  If 15.5 Mb represents 6.6% of the
   euchromatin arms then 15.5/0.066 = 234 Mb of genomic DNA would be
   calculated to represent the target non-overlapping genome space for
   the international genome sequencing project.  C) In a separate
   analysis, the 15.5 Mb of available tomato genomic DNA was searched
   for homologies to gene sequences and 2100 non-redundant gene models
   were identified following removal or transposon, viral and other
   repetitive sequences.  2100 genes out of 35,000 corresponds to 6%
   of the predicted gene space.  Correcting for the percentage of gene
   space present in the euchromatin arms (85%) we can calculate that
   6.0/0.85 = 7.05% of the target gene space has been covered.  If
   15.5 Mb represents 7.05% of the euchromatin arms then 15.5/0.0705 =
   220 Mb of genomic DNA would be calculated to represent the target
   genome space for the international genome sequencing project.

   <center>
   <table>
   <tr><th>Method</th><th>Sequencing Target</th></tr>
   <tr><td>Cytology</td><td>212 Mb</td></tr>
   <tr><td>Available Sequence and percent high quality gene models</td><td>234 Mb</td></tr>
   <tr><td>Available sequence and total gene models</td><td>220 Mb</td></tr>
   </table>
   </center>
</dd>
</dl>
<h4>Additional Information</h4>

<p> When the sequencing project is advanced to the stage where BAC
contigs can be assayed for both total non-redundant sequence length
and physical distance based on in situ hybridization, we will be able
to develop an additional estimate of euchromatin physical size through
validation of the cytological measurements with actual sequence data.
At present there is no data available to make such estimations though
the UK group has developed large BAC contigs covering most of
chromosome 4 that will move into their sequencing pipeline in coming
months.  Based on BAC FPC data alone they have reported that their
physical size estimate for chromosome 4 is consistent with the
original cytological estimates used in planning the international
sequencing effort (C. Nicholson, personal communication).  In
addition, the Korean group has completed more BAC sequencing than any
other group in the consortium to date with 49 finished BACs
representing approximately 20% of their projected total for chromosome
2.  In line with project plans they have started from BACs anchored to
the genetic map and spaced along chromosome 2.  As such, they still
have few and short contigs, rather representative sequence islands
across chromosome 2.  Nevertheless, based on the physical distances
between mapped marker sequences found in their sequenced BACs, they
have estimated that the BACs sequenced to date represent approximately
20% of the genetic map for chromosome 2.  While genetic to physical
distance ratios can vary widely, and these numbers could change
dramatically (for example in an area of suppressed recombination), at
present their available data is consistent with the original
cytological results on which the project was based.
</p>

<p>In summary, the data described above is consistent with a sequencing target of 212 - 234 Mb for completion of the objectives of the international tomato genome sequencing project. At present we propose use of the larger estimate, 234 Mb, to guide our project plan as it is likely more accurate and more conservative (in terms of justifying budget and activity for completion of project goals).
</p>
EOH
			 .info_section_html(title => '1.2 Sequencing standards',
					    is_subsection => 1,
					    contents => <<EOH)
<p>A "finished BAC" is defined as one:</p>
<ul>
<li>that contains an error rate of less than 1:10,000 bases and continuous sequence across the entire BAC (HTGS phase 3)</li>
<li>that has an average of 8-fold redundancy in sequencing coverage with a minimum of one high quality read in both directions at any given location</li>
<li>that is as gap-free as possible, given all reasonable state-of-the-art gap-filling approaches available at the time of sequencing</li>
</ul>

<p>
Regarding the euchromatin pseudomolecule, a small number of recalcitrant gaps, which will be physically defined by in situ hybridization, will be tolerated. Based on the degree of completion of the rice genome and excluding gaps defined by centromeres, this would mean approximately 4 - 6 gaps per tomato chromosome on average. Once all BACs in the minimal tiling path have been sequenced through two rounds of finishing, "Difficult" BACs (those that cannot be finished within two rounds of finishing) will be set aside and finished to the degree resources allow.  Similar strategies have been employed for rice and Medicago.
</p>
EOH
		       );

print info_section_html( title => '2. Completion criteria',
			 contents => <<EOH,
<p>
We shall use as our targeted sequencing goals two guiding principles: 1) complete sequencing of the major euchromatin "arms" flanking each of the 12 tomato chromosomes 2) to a degree of completion comparable to the standards of completion used to guide the international rice genome sequencing project (IRGSP, 2005) and enumerated above. We further define our objectives to include sequencing to at least the closest mapped marker to the visible euchromatin heterochromatin borders of each chromosome arm.  In situ hybridization will be used to determine if these borders define the true euchromatin/heterochromatin borders or a gap that will be at minimum physically defined and at maximum walked via the above strategy until characteristic heterochromatin repeats are reached (at which time FISH will be performed with the closest low copy BAC or internal BAC sequence).
</p>

<p>
Estimation of gene space missed in this approach.  Extrapolating from data obtained in rice we can calculate the number of genes that we might expect to miss in an approach that focuses on just the gene dense tomato euchromatin.  For example, sequencing of rice chromosome 8 revealed 86 active genes in the centromere proper and distal non-recombinant regions (Yan et al., 2005).  86 genes/centromere X 12 tomato chromosomes = 1032 centromeric genes. Prior to initiation of the international tomato sequencing effort, Exelexsis Biosciences sequenced and deposited two random BACs from heterochromatin with highly repetitive DNA, which together covered greater than 200 kb and harbored one gene.  While this is clearly limited data, we can make a further rough estimate that we might lose an additional (705,000 kb of DNA in heterochromatin divided by 200 kb per gene =) 3525 genes in heterochromatin or a total of approximately 4500 genes that could be missed by focusing solely on the euchromatin arms (see above for the 705,000 kb estimate of the heterochromatin).  The estimated gene content of tomato is 35,000 genes (Van der Hoeven et al., 2002) suggesting that approximately 35,000 - 4,500 = 30,500 genes (87%) might be anticipated to be recovered through the euchromatin-only approach. Correcting further for the fact that non-centromere gaps represented approximately 3% of the targeted sequence space in rice, we would estimate recovery of 85% of the tomato gene space (apx. 30,000 genes) under the efforts of the international tomato sequencing effort.  In summary, the target of the international genome sequencing effort is sequencing of the euchromatin arms of all twelve tomato chromosomes which we estimate will represent approximately 85% of the tomato gene space.
</p>
EOH
		       );

$page->footer;
