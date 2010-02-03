
use CXGN::Page;

my $page=CXGN::Page->new( "FastMapping Input Help", "?");

$page->header();

print <<HTML;

<h1>FastMapping Input Help</h1>
<h2>Input files</h2>

<p>FastMapping can analyze either a F2 intercross or backcross. FastMapping accepts 'raw' data files in a crosstable format
similar to that used by MAPMAKER. See <a href="http://visionlab.bio.unc.edu/MapConverter/docs/MAPMAKER.FEED.ME.txt">http://visionlab.bio.unc.edu/MapConverter/docs/MAPMAKER.FEED.ME.txt</a> for a thorough description
of the format MAPMAKER uses.</p>

<p>Raw files are plain ASCII files that vary little between Windows, UNIX and Mac, so you shouldn't have trouble transferring files between platforms. <b>FastMapping requires marker data to be in a tab-delimited format</b> that can be produced or read by Excel and other spreadsheet programs.</p>

<p>Your file should start with a header:</p>

<p>name = (file id)<br />
popt = (i.e. F2, BC1)<br />
nloc = (number of loci)<br />
nind = (number of progeny individuals)</p>

<p>Marker data should then be given tab-delimited:</p>

<p>(loci id)	A	D	B	B	B	-	A	H	H<br />
(loci id)	A	H	B	B	B	-	H	H	H<br />
(loci id)	A	C	C	C	-	C	C	C	C<br />
(loci id)	H	H	B	H	-	-	H	H	H<br />
(loci id)	A	H	B	B	-	H	H	H	H</p>

<p>where the following codes are used for genotypes:</p>

<p>Backcrosses (BC1):<br />

    'A'    Homozygote for the recurrent parent genotype.<br />
    'B'    Heterozygote.<br />
    '-'    Missing data for the individual at this locus.</p>

<p>For F2 intercross:<br />

    'A'    Homozygote for the allele from parental strain a of this locus.<br />
    'B'    Homozygote for the allele from parental strain b of this locus.<br />
    'H'    Heterozygote carrying both alleles a  and b.<br />
    'C'    Not a homozygote for allele a  (either bb  or ab  genotype.)<br />
    'D'    Not a homozygote for allele b  (either aa  or ab  genotype.)<br />
    '-'    Missing data for the individual at this locus</p>


<h2>Program Parameters</h2><p />

<a name="skipgrouping"></a><p><b>Skip Grouping</b><br />
If selected FastMapping will only try to order markers. This will make the next three parameters irrelevant</p>

<a name="linkage_groups"></a><p><b>Linkage groups</b><br />
FastMapping creates this number of independent groups in the first step of grouping<br />
Should be set to the predicted number of linkage groups or chromosomes.</p>

<a name="corelod"></a><p><b>Core LOD threshold</b><br />
LOD(logarithm of odds) threshold used during the creation of core groups. The "core" of a linkage group should consist of markers with few scoring errors, so this threshold can be set higher very high. Lower values increase the chance that two linkage groups could be undesirably merged. A too-high value may create artificial separation of linkage groups.</p>

<a name="lowlod"></a><p><b>Low LOD threshold</b><br />
Lower LOD threshold used to place less-certain markers. Typical set ~3, i.e. a marker is 1000 times more likely to be linked than not. Note that these thresholds should be higher for larger numbers of loci.</p>

<a name="missingvaluethresh"></a><p><b>Missing Value threshold</b><br />
Screens out markers with higher percentages of missing values.</p>

<a name="screening"></a><p><b>Segregation Ratio Screening</b><br />
Markers with segregation ratios that differ from the expected Mendelian ratios can be screened out. Screening is determined by a chi-squared test. Higher chi-squared thresholds are more lenient.</p>

<p><b>1:2:1</b> Chi-squared threshold for codominant F2 markers<br />
<b>1:3</b> Chi-squared threshold for dominant F2 markers<br />
<b>1:1</b> Chi-squared threshold for back-crossed populations</p>

<a name="order"></a><p><b>Order Individuals</b><br />
   If this option is selected, individuals will also be ordered using RECORD. This gives a better visual picture of the results. However, all data in the file will be ordered, so it makes little sense to use this option if there is more than one linkage group since FastMapping will try to order all linkage groups simultaneously</p>

HTML


$page->footer();
