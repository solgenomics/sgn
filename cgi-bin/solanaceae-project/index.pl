

use strict;
   
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/page_title_html blue_section_html toolbar_html/;

my $page=CXGN::Page->new('index.html','html2pl converter');

$page->header('International Solanaceae Project');

print page_title_html('International Solanaceae Genomics Project (SOL)<br />Systems Approach to Diversity and Adaptation');

print <<END_HEREDOC;
<div class="indentedcontent">
<table summary="">
<tr><td style="vertical-align: middle">
Over the coming decade the International Solanaceae Genome Project
(SOL) will create a coordinated network of knowledge about the
Solanaceae family aimed at answering two of the most important
questions about life and agriculture:
<ul>
<li>How can a common set of genes/proteins give rise to such a wide
range of morphologically and ecologically distinct organisms that
occupy our planet?</li>
<li>How can a deeper understanding of the genetic basis of
diversity be harnessed to better meet the needs of society in an
environmentally-friendly way?</li>
</ul>
On this page, you will find more information about the strategy
used to answer these questions. A
<a href="/static_content/solanaceae-project/docs/SOL_vision.pdf">whitepaper</a>
is available with more details. It contains contributions from
Solanaceae scientists around the world. The whitepaper and the
accompanying Powerpoint presentation are meant to be resources for
people who want to write grants in the International Solanaceae
framework. All texts and images can be used freely.</td>
<td>
  <div style="border: 1px outset black">
  <a href="/static_content/solanaceae-project/docs/SOL_vision.pdf">
    <img style="border: 0; margin: 1em" src="/static_content/solanaceae-project/SOL_title.jpg" alt="SOL Project Whitepaper Cover" />
  </a>
  </div>
</td>
</tr>
</table>
</div>
END_HEREDOC

print blue_section_html('SOL sites around the world', <<HTML);

<ul>
<li><a href="http://cnia.inta.gov.ar/lat-sol/">Lat-SOL</a> - South American SOL laboratories<br /></li>
<li><a href="http://www.srcuk.org/index.htm">SRCUK</a> - Solanaceae Research Community in the United Kingdom<br /></li>
</ul>

<a name="news" id="news"></a>

HTML

print blue_section_html('News',<<EOHTML);


<ul>
<li>Detailed instructions on how to perform the BAC validation procedure involving the IL lines, contributed by Giovanni Giuliano, are now available [<a href="/static_content/solanaceae-project/docs/BAC_mapping_validation_1.ppt">ppt</a>] [Mar 29, 2007].</li>
<li>The tomato genome sequencing guidelines on finishing have been thoroughly revised by Karen McLaren [<a href="http://docs.google.com/View?docid=dggs4r6k_1dd5p56">google doc</a>] [Mar 29, 2007].</li>
<li>The letter of intent for the pennellii sequencing project submitted to JGI <a href="/static_content/solanaceae-project/docs/pennellii.pdf">[pdf]</a> has been approved for a full proposal submission. Please consider writing a letter of support <a href="/static_content/solanaceae-project/docs/JGI_support_letter.doc">[draft letter doc]</a>. Send to <a href="mailto:jv27\@cornell.edu">jv27\@cornell.edu</a> by February 20, 2007.
<li>The SOL-100 white paper is available [Dec 5, 2006] [<a href="/static_content/solanaceae-project/docs/Position-SOL-100.pdf">pdf</a>]</li>
<li>A new document describing the basis of the euchromatin size of tomato is available [Sept 6, 2006]. [<a href="/static_content/solanaceae-project/docs/Euchromatin_size_just.pdf">pdf</a>]</li>
<li>The Dutch BAC extension protocol is now available! <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/STC_protocol.pdf">[pdf]</a> [Feb 3, 2006]</li>
<li>Australia has been added to the SOL countries write-up. [Aug 9, 2005]</li>
<li style="list-style-type:none">A new version of the seed BAC selection guidelines is available. [Jan 12, 2005]</li>
<li style="list-style-type:none">The next Solanaceae Genome Workshop 2005 will be held on the Island of Ischia, Italy. <span style="white-space: nowrap;"><a href="/solanaceae-project/meeting_2005/index.pl">More information</a> | <a href="http://www.solanaceae2005.org/">Meeting website</a>.</span></li>
<li>Tomato Sequencing Overview page is now <a href="/about/tomato_sequencing.pl">available</a> on SGN.</li>
<li>The California Tomato Research Institute, Inc. (CTRI) announces the formation of <a href="/community/snp_consortium/index.pl"> Tomato Public SNP Consortium </a></li>
</ul>

EOHTML

print blue_section_html('SOL Resources',<<EOHTML);
<dl>
<dt>SOL Bioinformatics pages</dt>
<dd><a href="sol-bioinformatics/index.pl">SOL bioinformatics pages</a> with
     meeting notes, powerpoint slides, etc
</dd>
<dt><a name="SOL_news" id="SOL_news"></a>SOL Newsletters</dt>
<dd> 
    <ul>
<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Mar_10.pdf">March 2010</a> <b>(current issue)</b></li>
<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Dec_09.pdf">December 2009</a></li>
<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Sept_09.pdf">September 2009</a></li>
<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Jun_09.pdf">June 2009</a></li>
<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Mar_09.pdf">March 2009</a></li>
<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Dec_08.pdf">December 2008</a></li>
<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Aug_08.pdf">August 2008</a> </li>
<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_May_08.pdf">May 2008</a> [<a href="/static_content/solanaceae-project/docs/postersolanaceaesymposium-2gvdw.pdf">Nijmegen symposium poster supplement</a>]</li>
<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Mar_08.pdf">March 2008</a></li>
        <li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Nov_07.pdf">November 2007</a></li>
	<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Jul_07.pdf">July 2007</a></li>
	<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_May_07.pdf">May 2007</a></li>
            <li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Mar_07.pdf">March 2007</a></b></li>
                <li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Jan_07.pdf">January 2007</a></li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Nov_06.pdf">November 2006</a>
			<a href="/static_content/solanaceae-project/docs/marker_sanmarzano.pdf">[Supplement]</a></li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Sep_06.pdf">September 2006</a></li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Jun_06.pdf">June 2006</a> </li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Apr_06.pdf">April 2006</a></li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Feb_06.pdf">Feb 2006</a></li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Nov_05.pdf">Nov 2005</a> </li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Sept_05.pdf">September 2005</a></li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_July_05.pdf">July 2005</a></li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_May_05.pdf">May 2005</a> and
			supplement <a  href="/static_content/solanaceae-project/docs/FISH_supplement.ppt">[ppt]</a></li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Mar_05.pdf">March 2005</a></li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Dec_04.pdf">December 2004</a></li>
		<li><a href="/static_content/solanaceae-project/docs/SOL_newsletter_Nov_04.pdf">November 2004</a></li>
	</ul>
</dd>
</dl>
<dl>
<dt>Seed BAC Selection Guidelines</dt>
<dd><a  href="/static_content/solanaceae-project/docs/Guideline_v2.pdf">[pdf]</a>&nbsp;<a  href="seed_bac_selection.pl">[html]</a></dd>
<dt>Updated whitepaper [Sept 4, 2004]</dt>

<dd>The updated whitepaper is now conveniently available in 5
parts:

<div style="margin-left: 1em">
  <table summary="">
  <tr>
    <td><a  href="/static_content/solanaceae-project/docs/SOL_vision.pdf">[pdf]</a></td>
    <td>Part I &ndash; The SOL vision</td>
    <td></td>
  </tr><tr>
    <td><a  href="/static_content/solanaceae-project/docs/solanaceae-crop.pdf">[pdf]</a></td>
    <td>Part II &ndash; Solanaceae Crops</td>
    <td></td>
  </tr><tr>
    <td><a  href="/static_content/solanaceae-project/docs/solanaceae-countries.pdf">[pdf]</a></td>
    <td>Part III &ndash; Solanaceae Countries</td>
    <td>[updated August 9, 2005]</td>
  </tr><tr>
    <td><a  href="/static_content/solanaceae-project/docs/tomato-sequencing.pdf">[pdf]</a></td>
    <td>Part IV &ndash; Tomato Sequencing Strategy</td>
    <td></td>
  </tr><tr>
    <td><!-- a  href="/static_content/solanaceae-project/docs/tomato-standards.pdf" -->
    <a href="http://docs.google.com/View?docid=dggs4r6k_1dd5p56">[Google doc]</a></td>
    <td>Part V &ndash; Bioinformatics Standards and Guidelines
<table><tr><td class="boxbgcolor4">Available as a Google document. <br />You can request edit privileges by <a href="mailto:sgn-feedback\@sgn.cornell.edu">contacting us</a>.</td></tr></table><br />
    </td>
    <td></td>
  </tr><tr>
    <td><a  href="/static_content/solanaceae-project/SOL.final.31_12.sent.ppt">[ppt]</a></td>
    <td>SOL Project presentation slides</td>
    <td>[updated December 31, 2003]</td>
  </tr>
  </table>
</div>
</dd>

<dt><a name="callforbacs" id="callforbacs">Call for BACs -
Sequencing your favorite BACs as part of SOL [March 11,
2004]</a></dt>

<dd>If you would like to have a specific tomato BAC sequenced as
part of the SOL tomato genome project, please submit it using
<a href="call_for_BACS.pl">these instructions</a>. BACs that
are anchored to a genetic map are considered with high
priority.</dd>
<dt>International Solanaceae Meeting [11/15/2003]
</dt>
<dd>
Location: Washington, D.C. (Holiday Inn Dulles International)<br />
<br />
Date: November 3, 2003<br />
<br />
The purpose of the meeting was to determine the feasibility,
utility, strategy and level of international interest/commitment
for sequencing the tomato genome as a reference for the family
Solanaceae and other closely related plant families. The workshop
brought together and international group of scientists to discuss:
<ol>
<li>the current status of Solanaceae research - including aspects of
plant biology for which Solanaceous species are a preferred model,</li>
<li>the impact of sequencing the tomato genome on research in the
Solanaceae and plant biology in general,</li>
<li>sequencing strategy,</li>
<li>mechanisms by which such a sequencing project can be conducted
as part of a multinational consortium, and 5) strategies for
sequence information management, curation and public
dissemination.</li>
</ol>
Complete meeting summary:
<a  href="summary.pl">[html]</a>
<a  href="/static_content/solanaceae-project/summary.pdf">[pdf (U.S. letter)]</a> 
<a  href="/static_content/solanaceae-project/summary_A4.pdf">[pdf (A4)]</a> 
<a  href="/static_content/solanaceae-project/summary.doc">[doc]</a>
</dd>
</dl>

EOHTML

$page->footer();
