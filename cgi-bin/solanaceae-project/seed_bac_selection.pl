use strict;
use CXGN::Page;
my $page=CXGN::Page->new('seed_bac_selection.html','html2pl converter');
$page->header('SGN: Seed BAC selection guidelines');
print<<END_HEREDOC;


<center>



<table summary="" width="720" cellpadding="0" cellspacing="0" border="0">
<tr><td>

<h3>Guideline for selecting seed BACs</h3>

<p>The BAC stabs (or rearrayed BAC clones) are made directly from frozen glycerol stocks. Therefore, streaking the glycerol stock and picking a single colony are strongly suggested for confirming marker-BAC associations and selecting seed BACs.  However, if the BAC stab is made from single BAC clone/colony, it will be clearly stated in the shipping documentations.</p>

<p><strong>Confirming the hybridization of genetic markers with BAC clones:</strong></p>

<ol>
<li>
<p>Verifying marker-BAC association by sequencing BAC clone using a customized primer</p>
<p><u>Select two candidate seed BACs</u>: If possible, two seed BACs are suggested for each marker based on the estimated clone size.  The size of the selected BAC should be &gt;100 Kb, if possible.  If BACs with large inserts are not available, BACs with smaller insert size of 60 to 100 Kb or unknown insert size from plate 1-260 could be selected.  (Note: plate 1-260 of the HindIII library are from a ligation yielding larger insert clones).</p>
<p><u>Verifying by direct sequence BAC using a customized primer</u>: A customized primer is designed close to, but not overlapping, the overgo probe in the marker sequences.  A distance of approximately two to three hundred bases between the overgo probe and the customized primer is ideal to provide sufficient sequence for alignment confirmation.  Because most of the SGN markers are developed from EST sequences, SGN tool <a href="/tools/intron_detection/find_introns.pl">"Intron Finder"</a> should be used to predict splice sites for facilitating the primer design.  Then, the BAC can be sequenced using the customized primer.  One end (SP6 or T7 for the HindIII BAC library) of the BAC clone should be sequenced to confirm the quality of the BAC DNA.  If the BAC end sequence is good and the sequence from customized primer fails, an alternative customized primer should be designed and used for sequencing.  High quality BAC sequence obtained from the customized primer should be aligned with marker sequence.  If sequences align perfectly or near perfectly, then the BAC clone is considered verified.</p>
</li>
<li>
<p>Rehybridizing BAC clones using overgo probes developed from the genetic markers.</p>
<p>DNA from BAC clones anchored to one genetic marker should be prepared from the overnight culture with 12.5 mg/&micro;l
chloramphenicol. After BAC DNA is completely digested with HindIII (overnight or &gt;5 hrs), DNA fragments are electrophoresed and transferred onto a Hybond+ filter. Then Southern hybridization with the overgo probe designed for the genetic marker is conducted. Positive BACs are the plausible candidate seed BACs.  The sizes of HindIII digested fragments used for FPC are currently available upon request and will be available on <a href="/">SGN</a> in the near future.</p>
<p>The Southern hybridization can also be performed on filters containing NotI digested DNA (good for evaluating the insert size on CHEF gel) or BAC colony stamps from the overnight culture.</p>
</li>
<li>
<p>PCR amplification of genetic markers from the BAC clones</p>
<p>PCR primers can be designed from the sequence of a genetic marker (Note: For some markers, primers are already available in <a href="/">SGN database</a>). Results from PCR amplifications using BAC DNA as template can be used to validate the BAC-marker association.  Please be aware that most of the genetic markers are developed from tomato ESTs and PCR amplification might be problematic due to introns, which could be predicted using the SGN tool <a href="/tools/intron_detection/find_introns.pl">"Intron Finder"</a>.</p>
</li>
</ol>

<p><strong>Verifying the location of BACs on chromosome</strong></p>

<ul style="list-style-type:none">
<li><p>1. Fluorescence In-situ Hybridization (FISH)</p></li>
<li><p>2. Mapping in tomato IL lines (CAPS mapping in tomato IL lines)</p></li>
<li><p><u>Search SGN for known information</u>: If a candidate seed BAC has a confirmed marker-BAC association.  The original genetic anchor marker information should be searched from <a href="/">SGN database</a> for any known polymorphyism between M82 (<em>S. lycopersicum</em>) and <em>S. pennellii</em>.  If known information if available, the original CAPS information could be used for IL mapping.</p></li>
<li><p><u>Identifying sequence or digestion polymorphism</u>: If there is no polymorphism information available in <a href="/">SGN database</a>, the BAC sequence (BAC ends or sequence from the customized primer) can be compared with tomato ESTs or other sequenced genomes to identify conserved coding sequences.  PCR primers should be designe dfrom conserved coding regions.  DNA fragments from <em>S. pennellii</em> and M82 (two parents of the IL populations) can be amplified and sequenced to search sequence and enzyme digestion polymorphism.</p></li>
<li><p><u>IL mapping</u>: DNA of the chromosome ILs is amplified and the products are digested with a selected enzyme.  If the BAC maps to the chromosome, we will see the <em>S. pennellii</em> polymorphism on one or more of the ILs. The if sequence maps to a different chromosome, the <em>S. pennellii</em> polymorphism will not be found on the ILs and then the entire set of lines will have to be amplified in order to map the BAC.</p></li>
<li><p>(Note: <a href="mailto:zamir\@agri.huji.ac.il">Dr. Dani Zamir</a> will supply the genomic DNA of <em>S. pennellii</em>, M82 and ILs upon request.)</p></li>
</ul>

<p><strong>Selecting seed BACs:</strong></p>

<p>Criteria for selecting a BAC clone:</p>
<ol>
<li>large insert size (&gt;100kb, if possible, or with unknown insert size)</li>
<li>reconfirm by sequencing, overgo hybridization or PCR amplification</li>
<li>BAC physical location are tested using FISH or mapping in IL lines</li>
<li>in a valid FPC BAC contig (optional)</li>
</ol>

<p><strong>Selecting the first extension BACs:</strong></p>

<ol>
<li>minimum overlap (5 to 10 Kb) with seed BACs anchored to nearby genetic markers.  Overlap should not be to extensive to avoid redundant sequencing.</li>
<li>confirmed by FISH or IL mapping on the same chromosome as the seed BAC. (Note: BAC end sequences are available on <a href="/search/direct_search.pl?search=bacs">SGN</a>, which should be used to verify the size of overlapping regions and pick the extension tilling path BACs)</li>
</ol>

</td>
</tr>
</table>



</center>
END_HEREDOC
$page->footer();
