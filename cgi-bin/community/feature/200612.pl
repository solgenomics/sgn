
use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / page_title_html /;

my $page = CXGN::Page->new();
$page->header();
my $title = page_title_html("Coffee Bioinformatics Lab/ National Coffee Research Center/ Chinchina Colombia");

print <<HTML;

<center><b>Featured Lab</b></center>

$title

<center><img src="/static_content/community/feature/200612-1.jpg" alt="" /></center>

<p class="tinytype">CENICAFE Bioinformatics lab as of November 2006:
From Left to Right: Alvaro Gaitan and Marco Cristancho, Bioinformatics Analysts; Andres Chalarca, Carlos Orozco, and Luis Rivera, Bioinformatics developers</p>


<p>CENICAFE is the National Coffee Research Center located in Chinchina, Colombia. As part of its research, CENICAFE embarked in 2004 on a major project to study the genome of the species Coffea arabica and a major component of this research is the development of a Bioinformatics platform.</p>
<p>Our Bioinformatics group has worked in close collaboration with Dr. Lukas Mueller at Cornell University and Dr. Robin Buell at The Institute for Genomic Research-TIGR for the development of the platform. The system implemented several new tools and databases for the analysis of other organisms sequence data such as fungi and insects, based on SGN and TIGR database developments and implementation of several of their sequence analyses tools.</p>
<p>The Bioinformatics platform includes a Laboratory Integrated Management System (LIMS), the implementation of wEMBOSS, home-developed perl tools for data analysis, InterproScan for annotation of sequence domains, and the implementation of wBLAST and wNetBLAST among other tools available. As mentioned above, databases have been developed based on SGN and TIGR schemas for ESTs, Molecular Markers and BAC sequences storage and analysis, and the system is based on the postgresQL relational database, the use of perl scripts for the manipulation of data, the Apache Web server with the mod_perl integrated perl interpreter, and the servers run the Debian distribution of the GNU/Linux operating system.</p>
<p>Some of the major milestones of the coffee genome project at Cenicafe include to date (Nov 2006) the construction of over 15 coffee cDNA libraries (containing tissue specific, methyl filtrated, differential and normalized libraries), the sequencing and assembly of 50.000 ESTs, construction of an 9X coverage BAC library,  access to 80.000 BAC-end sequences, and development of coffee genome functional studies including Microarrays, Real Time-PCR and proteomics.</p>
<p>We are currently implementing in the system a coffee germplasm resource database developed at Cenicafe's Coffee Breeding Department, a proteomics platform, a NIRs database, a coffee map visualization system and a Microarray database.</p>

<p>Our group's website is available at <a href="http://bioinformatics.cenicafe.org/">http://bioinformatics.cenicafe.org/</a>.</p>
<br />
<center><img src="/static_content/community/feature/200612-2.jpg" alt="" /></center>

<p class="tinytype">CENICAFE is carrying out the study of the genomes of three organisms: coffee (red), the coffee berry borer (black), and the fungus Beauveria bassiana (white). By studying the three genomes the whole picture of their interactions is emerging.</p>

HTML


$page->footer();
