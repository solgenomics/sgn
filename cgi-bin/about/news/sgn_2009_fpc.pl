
use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw | page_title_html |;

my $page = CXGN::Page->new();

$page->header();

my $title = page_title_html("Announcement");

print <<HTML;

$title

<h1>October 30, 2009</h1>

<h2>New SNaPshot Physical Map of Tomato Available</h2>

<table width="70%" align="center" alt="Tomato FPC build announcement"><tr><td>
<p>We are pleased to announce the creation and full public release of a new physical map of tomato to assist in completion of the international tomato genome sequencing effort and to broadly promote public and private research on tomato.  This map represents approximately 10X BAC coverage of the tomato genome and takes advantage of clones from four independent BAC libraries (HindIII, EcoRI, and MboI genome partials in addition to a sheared genomic library).  The map can be accessed through the physical map link of SGN (<a href="http://solgenomics.net">http://solgenomics.net/</a>) and the full assembly can be retrieved from our ftp site (<a href="ftp://ftp.solgenomics.net">ftp://ftp.solgenomics.net/</a>).  We are in the process of adding a small set of additional anchor BACs and will then proceed with manual editing to improve the map.  Updates will be made and announced on SGN.  The map and all underlying BAC clones are available to the public without restriction.  We encourage your use of this new resource and your comments.</p>

<p>The map was created by the <a href="http://www.genome.arizona.edu">Arizona Genomics Institute</a> with funding from the <a href="http://www.nsf.gov/">United States National Science Foundation</a> (<a href="http://www.nsf.gov/awardsearch/showAward.do?AwardNumber=08-20612">Plant Genome Program Grant 08-20612</a> awarded to the <a href="http://bti.cornell.edu/">Boyce Thompson Institute for Plant Research</a>).  The four underlying BAC libraries were also created using NSF funds (<a href="http://www.nsf.gov/awardsearch/showAward.do?AwardNumber=06-05659">Plant Genome Program Grant 06-05659</a>) with the sheared BAC library being a joint effort with the <a href="http://www.eu-sol.net">EU-SOL consortium</a> (FOOD-CT-2006-016214). </p>

<p>Please contact <a href="mailto:sgn-feedback\@solgenomics.net">SGN</a> for more information.</p>

</td></tr></table>

HTML

$page->footer();
