
use strict;
use Tie::Function;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ page_title_html info_section_html blue_section_html/;

my $page=CXGN::Page->new('SOL Bioinformatics','Lukas');
$page->header('SOL Bioinformatics Page');

print page_title_html("SOL Bioinformatics Resources");

print info_section_html(title => 'Documents',
			contents => <<EOHTML,
<ul>
<li><a href="http://docs.google.com/View?docid=dggs4r6k_1dd5p56">[Google doc]</a> SOL Bioinformatics Standards and Guidelines</li>
<li><a href="http://www.ab.wur.nl/TomatoWiki">[Wiki]</a> ITAG Wiki</li>
<li><a href="/static_content/solanaceae-project/docs/BAC_mapping_validation_1.ppt">[ppt]</a> Detailed IL-BAC mapping protocol. </li>
</ul>
EOHTML
		       );

print info_section_html(title => 'Meeting Records',
			contents => <<EOHTML
<a href="index.pl">[odt]/[odp]</a> &ndash; indicates
 OpenDocument format, see <a href="http://www.openoffice.org">http://www.openoffice.org</a><br />
<a href="index.pl">[sxi]</a> &ndash; indicates OpenOffice 1.x format, see <a href="http://www.openoffice.org">http://www.openoffice.org</a><br />
<a href="index.pl">[ppt]</a> &ndash; indicates Microsoft Powerpoint format<br />
<a href="index.pl">[txt]</a> &ndash; indicates plain text format<br />
<a href="index.pl">[pdf]</a> &ndash; indicates PDF format<br /><br />
EOHTML


			.info_section_html(title => 'SOL 2010 Sequencing Meeting',
					   subtitle => 'Tuesday, Sep 7, 2010',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Apex Hotel, Dundee, UK</dd>
<dt>Notes</dt>
<dd>
  meeting minutes by Joyce van Eck <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2010_docs/vanEck_notes.txt">[txt]</a><br />
</dd>
</dl>
EOHTML
			.info_section_html(title => 'PAG 2010 Sequencing Meeting',
					   subtitle => 'Tuesday, Jan 12, 2010',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Town and Country Hotel, San Diego, CA, USA</dd>
<dt>Progress Reports</dt>
<dd>Assembly Progress: Sandra Smit <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2010_docs/pag2010_assembly_progress.pdf">[pdf]</a></dd>
<dt>Notes</dt>
<dd>Meeting Summary <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2010_docs/pag2010_meeting_notes.docx">[doc]</a></dd>
</dl>

EOHTML

			.info_section_html(title => 'EU-SOL Next Gen Assembly Workshop',
					   subtitle => 'Wednesday, July 15, 2009 12am-5pm',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Schiphol Airport, The Netherlands</dd>
<dt>Progress Reports</dt>
<dd>
USA: Lukas Mueller <a href="/static_content/solanaceae-project/sol-bioinformatics/nextgen_docs/mueller.ppt">[ppt]</a><br />
UK: Gerard Bishop <a href="/static_content/solanaceae-project/sol-bioinformatics/nextgen_docs/bishop.ppt">[ppt]</a><br />
France: Mondher Bouzayen <a href="/static_content/solanaceae-project/sol-bioinformatics/nextgen_docs/bouzayen.ppt">[ppt]</a><br />
Italy: Giorgio Valle <a href="/static_content/solanaceae-project/sol-bioinformatics/nextgen_docs/valle.ppt">[ppt]</a>
</dd>
<dt>Other Presentations</dt>
<dd>
Roeland van Ham &ndash; General Outline of the Proposed Assembly Strategy <a href="/static_content/solanaceae-project/sol-bioinformatics/nextgen_docs/vanham.ppt">[ppt]</a><br />
Antoine Janssen &ndash; The Tomato Whole Genome Profiling Map <a href="/static_content/solanaceae-project/sol-bioinformatics/nextgen_docs/janssen.ppt">[ppt]</a>
</dd>
<dt>Notes</dt>
<dd>
Meeting Agenda <a href="/static_content/solanaceae-project/sol-bioinformatics/nextgen_docs/agenda.pdf">[pdf]</a>
</dd>
</dl>
EOHTML

			.info_section_html(title => 'PAG 2009 Sequencing Meeting',
					   subtitle => 'Sunday, Jan 11, 2009 10am-3:30pm',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Town and Country Hotel, San Diego, CA, USA</dd>
<dt>Progress Reports</dt>
<dd>
Chr 1 (USA): Joyce Van Eck <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2009_docs/chr1.ppt">[ppt]</a><br />
Chr 2 (Korea): Doil Choi <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2009_docs/chr2.ppt ">[ppt]</a><br />
Chr 3 (China): Ying Wang <span class="ghosted"">[ppt]</span><br />
Chr 4 (UK): Gerard Bishop <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2009_docs/chr4.ppt">[ppt]</a><br />
Chr 7 (France): Mondher Bouzayen <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2009_docs/chr7.ppt">[ppt]</a><br />
Chr 12 (Italy): Giovanni Giuliano <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2009_docs/chr12.ppt">[ppt]</a>
</dd>
<dt>Other Presentations</dt>
<dd>
Todd Vision &ndash; <i>Mimulus guttatus</i> sequencing progress <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2009_docs/Vision_mimulus.ppt">[ppt]</a><br />
Steven Stack &ndash; Role of FISH in tomato sequencing <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2009_docs/stack_fish.ppt">[ppt]</a><br />
Roeland van Hamm &ndash; Whole-genome shotgun sequencing for tomato<a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/rvh_wgs.ppt">[ppt]</a><br />
</dd>
<dt>Notes</dt>
<dd>
Meeting Agenda (Joyce Van Eck) <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2009_docs/Agenda.pdf">[pdf]</a><br />
meeting notes by Robert Buels <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2009_docs/Buels_notes.txt">[txt]</a><br />
</dd>
</dl>
EOHTML
			.info_section_html(title => 'SOL 2008 Sequencing Meeting',
					   subtitle => 'Wednesday, Oct 15, 2008 7pm-11pm',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Holiday Inn Cologne am Stadtwald, Cologne, NRW, Germany</dd>
<dt>Progress Reports</dt>
<dd>
Chr 1 (USA): Jim Giovannoni <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/chr1.ppt">[ppt]</a><br />
Chr 2 (Korea): Doil Choi <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/chr2.ppt ">[ppt]</a><br />
Chr 3 (China): Chuanyou Li <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/chr3.ppt ">[ppt]</a><br />
Chr 4 (UK): Gerard Bishop <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/chr4.ppt">[ppt]</a><br />
Chr 5 (India): Akhilesh Tyagi <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/chr5.ppt">[ppt]</a><br />
Chr 6 (Netherlands): Sander Peters <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/chr6.ppt">[ppt]</a><br />
Chr 7 (France): Mondher Bouzayen <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/chr7.ppt">[ppt]</a><br />
Chr 8 (Japan): Shusei Sato <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/chr8.ppt">[ppt]</a><br />
Chr 9 (Spain): Joyce Van Eck for A. Granell <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/chr9.ppt">[ppt]</a><br />
Chr 11 (China): not present<br />
Chr 12 (Italy): Giovanni Giuliano <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/chr12.ppt">[ppt]</a>
</dd>
<dt>Other Presentations</dt>
<dd>
Roeland van Hamm &ndash; Whole-genome shotgun sequencing proposal<a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/rvh_wgs.ppt">[ppt]</a><br />
</dd>
<dt>Notes</dt>
<dd>
meeting notes by Robert Buels <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/Buels_notes.txt">[txt]</a><br />
</dd>
<dt>Supplementary Material</dt>
<dd>Titanium-series 454 sequencing overview (from Roche) <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2008_docs/454.pdf">[pdf]</a>
</dd>
</dl>
EOHTML
			.info_section_html(title => 'Wageningen Finishing meeting 2008',
					   subtitle => 'Thu, Apr 24 - Fri Apr 25, 2008, 9:00am-5pm',
					   is_subsection => 1,
					   contents => <<EOHTML)



<dl>
<dt>Location</dt>
<dd>Wageningen Conference Center (WICC), Netherlands</dd>
<dt>Presentions</dt>
<dd>

<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/chr2_Jo.ppt">Chromosome 2 update</a> H. Jo<br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/chr3_Wang.ppt">Chromosome 3 update</a> Y. Wang<br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/chr4_Beasley.ppt">Chromosome 4 update</a> H. Beasley<br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/chr5_Sharma.ppt">Chromosome 5 update</a> T.R. Sharma<br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/chr6_Peters.ppt">Chromosome 6 update</a> S. Peters<br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/chr7_philippot.ppt">Chromosome 7 update</a> M. Philippot<br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/chr8_Sato.ppt">Chromosome 8 update</a> S. Sato<br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/chr9_Zuniga.ppt">Chromosome 9 updat</a> S. Zuniga<br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/chr11_Zhang.ppt">Chromosome 11 update</a> Z. Zhang<br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/chr12_Falcone.ppt">Chromosome 12 update</a> J. Falcone<br />

</dd>
<dt>Presentations about discussion topics</dt>
<dd>
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/Sanger_finishing_tools.ppt">Sanger Finishing Tools</a><br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/Solexa_Truco.ppt">Solexa Issues</a> <br />
<a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_wageningen_2008_docs/Discussion_McLaren.ppt">Discussion slides</a> (K. McLaren)<br />
</dd>
</dl>
       
<table><tr><td><br />This meeting was organized by the EU-SOL project.</td><td width="30">&nbsp;</td><td> <a href="http://www.eu-sol.net" class="footer"><img src="/documents/img/eusol_logo_small.jpg" /></a></td></tr></table>                        
EOHTML




			.info_section_html(title => 'PAG 2008 meeting',
					   subtitle => 'Sun, Jan 13, 2008, 9:00am-4pm',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>The Boardroom, Town and Country Hotel, San Diego, California, USA</dd>
<dt>Progress Reports</dt>
<dd>
Chr 1 (USA): Joyce Van Eck <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/VanEck.ppt">[ppt]</a><br />
Chr 2 (Korea): Doil Choi <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Choi.ppt ">[ppt]</a><br />
Chr 3 (China): Mingsheng Chen <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Chen.ppt ">[ppt]</a><br />
Chr 4 (UK): Clare Riddle <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Riddle.ppt">[ppt]</a><br />
Chr 5 (India): Nagendra Singh <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Singh.ppt">[ppt]</a><br />
Chr 6 (Netherlands): Rene Klein-Lankhorst <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/RKL.ppt">[ppt]</a><br />
Chr 7 (France): Mondher Bouzayen <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Bouzayen.ppt">[ppt]</a><br />
Chr 9 (Spain): not present<br />
Chr 11 (China): Sanwen Huang <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Huang.ppt">[ppt]</a><br />
Chr 12 (Italy): Alessandro Vezzi <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Vezzi.ppt">[ppt]</a>
</dd>
<dt>Other Presentations</dt>
<dd>
Hans de Jong &ndash; BAC FISH and repeat bar-coding technology for tomato and potato <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/DeJong.ppt">[ppt]</a><br />
Giovanni Giuliano &ndash; Finishing Criteria <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Giuliano_finishing.ppt">[ppt]</a><br />
Mingsheng Chen &ndash; Towards an Integrated Physical Map of the Tomato Genome <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Chen_physical.ppt">[ppt]</a><br />
Steven Stack &ndash; Role of FISH in Tomato Genome Sequencing <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Stack.ppt">[ppt]</a><br />
</dd>
<dt>Notes</dt>
<dd>
Meeting Agenda (Joyce Van Eck) <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Agenda.doc">[doc]</a><br />
a few notes by Robert Buels <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2008_docs/Buels_notes.txt">[txt]</a><br />
</dd>
</dl>
EOHTML

			.info_section_html(title => 'SOL 2007 meeting',
					   subtitle => 'Fri, Sept 14, 2007, 8:30am-4pm',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Ramada Plaza Jeju, Jeju City, Korea</dd>
<dt>Progress Reports</dt>
<dd>
Chr 1 (USA): Jim Giovannoni <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Giovannoni.ppt">[ppt]</a><br />
Chr 2 (Korea): Sunghwan Jo <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Jo.ppt ">[ppt]</a><br />
Chr 3 (China): not present<br />
Chr 4 (UK): Gerard Bishop <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Bishop_chr4update.ppt">[ppt]</a><br />
Chr 5 (India): J.P. Khurana <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Khurana.ppt">[ppt]</a><br />
Chr 6 (Netherlands): Sander Peters <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Peters.ppt">[ppt]</a><br />
Chr 7 (France): Mondher Bouzayen <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Bouzayen.ppt">[ppt]</a><br />
Chr 8 (Japan): Erika Asamizu (presented earlier in main conference session)<a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Asamizu.ppt">[ppt]</a><br />
Chr 9 (Spain): Antonio Granell<br />
Chr 12 (Italy): Mara Ercolano <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Ercolano.ppt">[ppt]</a>
</dd>
<dt>Other Presentations</dt>
<dd>
Rene Klein-Lankhorst &ndash; Using FISH to determine euchromatin/heterochromatin boundaries <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/KleinLankhorst.ppt">[ppt]</a><br />
Mondher Bouzayen &ndash; Alternative methods for BAC anchoring <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Bouzayen.ppt">[ppt]</a><br />
Gerard Bishop &ndash; Sequencing standards update <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Bishop_standards.ppt">[ppt]</a><br />
Stephane Rombauts &ndash; ITAG Pipeline <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Rombauts.pdf">[pdf]</a><br />
</dd>
<dt>Notes</dt>
<dd>
Meeting Summary (Giovannoni, Mueller, Van Eck) <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Summary_Giovannoni_Mueller_VanEck.doc">[doc]</a><br />
a few notes by Daniel Buchan <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Buchan_notes.doc">[doc]</a><br />
a few notes by Robert Buels <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2007_docs/Buels_notes.txt">[txt]</a><br />
</dd>
</dl>
EOHTML

.info_section_html(title => '1st International Tomato Finishing Meeting',
					   subtitle => 'Mon, Apr 16 - Tues, Apr 17, 2007',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Sanger Centre, Hinxton, UK</dd>
<dt>Talk Slides</dt>
<dd>
Mapping presentation by Christine Nicholson <a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_sanger_2007_docs/WORKSHOP_MAPPING_TALK.ppt">[ppt]</a><br />
Finishing presentation by Helen Beasley <a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_sanger_2007_docs/hr1_tomato_finishing_workshop_april_2007_final_monday.ppt">[ppt]</a> <br />

Meeting Report [Karen McLaren] <a href="/static_content/solanaceae-project/sol-bioinformatics/finishing_sanger_2007_docs/meeting_report_karen.pdf">[pdf]</a>

EOHTML


			.info_section_html(title => 'PAG 2007 meeting',
					   subtitle => 'Sun, Jan 14, 2007',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Terrace Salon 3, Town and Country Hotel, San Diego, California, USA</dd>
<dt>Progress Reports</dt>
<dd>
Chr 1 (USA): Jim Giovannoni <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_up1_jg.ppt">[ppt]</a><br />
Chr 2 (Korea): Doil Choi <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_up2_dc.ppt">[ppt]</a><br />
Chr 3 (China): not present<br />
Chr 4 (UK): Christine Nicholson <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_up4_cn.ppt">[ppt]</a><br />
Chr 5 (India): Paramjit Khurana <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_up5_pk.ppt">[ppt]</a><br />
Chr 6 (Netherlands): Rene Klein-Lankhorst <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_up6_rkl.ppt">[ppt]</a><br />
Chr 7 (France): not present<br />
Chr 8 (Japan): not present<br />
Chr 9 (Spain): Antonio Granell <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_up9_ag.ppt">[ppt]</a><br />
Chr 12 (Italy): Mara Ercolano <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_up12_gg.ppt">[ppt]</a>
</dd>
<dt>Other Presentations</dt>
<dd>
Rene Klein-Lankhorst &ndash; Using FISH to determine euchromatin/heterochromatin boundaries <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_rkl_eusol.ppt">[ppt]</a><br />
Jim Giovannoni &ndash; Discussion on BAC extension protocols <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_jg_bacext.ppt">[ppt]</a><br />
Jim Giovannoni &ndash; US Contribution to Sequencing <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_jg_us_seq.ppt">[ppt]</a><br />
Robert Buels &ndash; BAC submission and annotation protocols and tools <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_rb.odp">[odp]</a> <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_rb.ppt">[ppt]</a><br />
Giovanni Giuliano &ndash; Tomato Affy chip <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_gg_affy.ppt">[ppt]</a><br />
Nevin Young &ndash; <i>Medicago truncatula</i> sequencing update<a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_ny.ppt">[ppt]</a><br />
Matthew Lorence &ndash; Tomato Affy chip <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_ml_affy.ppt">[ppt]</a><br />
Christian Bachem &ndash; Potato Genome Initiative <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_cb.ppt">[ppt]</a><br />
Syngenta &ndash; Contribution of BAC mapping to sequencing effort <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_syngenta_fpc.ppt">[ppt]</a><br />

<dt>Agenda</dt>
<dd>by Joyce Van Eck <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_agenda.doc">[doc]</a></dd>
</dd>
<dt>Minutes</dt>
<dd>
Notes by Joyce van Eck <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_notes_jve.pdf">[pdf]</a>.<br/>
A few notes by Robert Buels <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2007_docs/pag2007_notes_rb.txt">[txt]</a>.
</dd>
</dl>
EOHTML
			.info_section_html(title => 'Ghent 2006 Tomato Annotation meeting',
					   subtitle => 'Mon, Oct 23-25, 2006',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>LEAF Conference Room, Flanders Interuniversity Institute for Biotechnology, Ghent, Belgium</dd>
<dt>Meeting Summary</dt>
<dd>by Lukas Mueller and Robert Buels <a href="/solanaceae-project/sol-bioinformatics/ghent2006_report.pl">[html]</a> <a href="/static_content/solanaceae-project/sol-bioinformatics/ghent2006_docs/report.odt">[odt]</a></dd>
<dt>Presentations</dt>
<dd>
New Developments at SGN: Lukas Mueller <a href="/static_content/solanaceae-project/sol-bioinformatics/ghent2006_docs/mueller.odp">[odp]</a><br />
Cyrille2 Tomato Annotation: Mark Fiers and Erwin Datema <a href="/static_content/solanaceae-project/sol-bioinformatics/ghent2006_docs/datema.ppt">[ppt]</a><br />
Training GeneID: Francisco Camara <a href="/static_content/solanaceae-project/sol-bioinformatics/ghent2006_docs/camara.ppt">[ppt]</a><br />
India Sequencing Progress: Saloni Mathur <a href="/static_content/solanaceae-project/sol-bioinformatics/ghent2006_docs/mathur.ppt">[ppt]</a><br />
</dd>
</dl>
EOHTML
			.info_section_html(title => 'SOL 2006 meeting',
					   subtitle => 'Wed, Aug 26, 2006, 8:30am-11:45am',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Hall of Ideas Room E, Monona Terrace Convention Center, Madison, Wisconsin, USA</dd>
<dt>Progress Reports</dt>
<dd>
Chr 1 (USA): Jim Giovannoni <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/Giovannoni.ppt">[ppt]</a><br />
Chr 2 (Korea): Sung-Hwan Cho <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/Cho.ppt ">[ppt]</a><br />
Chr 3 (China): Eileen Wang <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/Wang.ppt">[ppt]</a><br />
Chr 4 (UK): Christine Nicholson and Karen McLaren <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/Nicholson.ppt">[ppt]</a><br />
Chr 5 (India): Jitendra Khurana <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/Khurana.ppt">[ppt]</a><br />
Chr 6 (Netherlands): Roeland van Hamm <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/vanHamm.ppt">[ppt]</a><br />
Chr 7 (France): Farid Regad <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/Regad.ppt">[ppt]</a><br />
Chr 8 (Japan): Erika Asamizu <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/Asamizu.ppt">[ppt]</a><br />
Chr 9 (Spain): Antonio Granell <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/Granell.ppt">[ppt]</a><br />
Chr 12 (Italy): Silvana Grandillo <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/Grandillo.ppt">[ppt]</a>
</dd>
<dt>Minutes</dt>
<dd>
notes by Robert Buels and Marty Kreuter <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/buels_notes.txt">[txt]</a><br />
notes by Lukas Mueller (includes potato session and afternoon bioinformatics session) <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2006_docs/mueller_notes.txt">[txt]</a>
</dd>
</dl>
EOHTML
			.info_section_html(title => 'PAG 2006 meeting',
					   subtitle => 'Sun, Jan 16, 2006, 1pm-6pm',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Dover Room, Town and Country Hotel, San Diego, California, USA</dd>
<dt>Progress Reports</dt>
<dd>
Chr 1 (USA): Lukas Mueller<br />
Chr 2 (Korea): not present<br />
Chr 3 (China): Eileen Wang <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/2006PAG_Chromosome_3_update.ppt">[ppt]</a><br />
Chr 4 (UK): Christine Nicholson <!-- <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/2006PAG_Chromosome4_UK.ppt">[ppt]</a> --><br />
Chr 5 (India): not present<br />
Chr 6 (Netherlands): Rene Klein-Lankhorst <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/chr6_SOL_lezing_San_Diego__2006.ppt">[ppt]</a><br />
Chr 7 (France): not present<br />
Chr 8 (Japan): not present<br />
Chr 9 (Spain): not present<br />
Chr 12 (Italy): Giovanni Giuliano  <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/Giuliano_PAG.ppt">[ppt]</a> and Giorgio Valle <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/Valle_PAG.ppt">[ppt]</a>
</dd>
<dt>Other Presentations</dt>
<dd>
Remy Bruggman &ndash; Training Gene Finders for Tomato <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/Bruggmann_SanDiego_January_2006.ppt">[ppt]</a><br />
Robert Buels &ndash; Submitting BACs to SGN <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/submission_system_PAG_2006.sxi">[sxi]</a> <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/submission_system_PAG_2006.ppt">[ppt]</a><br />
Stephen Stack &ndash; Tomato FISH <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/stack_FISH_talk.ppt">[ppt]</a><br />
Naama Menda &ndash; Ontologies for Describing Solanaceae Phenotypes <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/menda_SOL_PAG06.sxi">ppt</a><br />
</dd>
<dt>Minutes</dt>
<dd>
a few notes by Robert Buels <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/buels_notes_pag2006.txt">[txt]</a>.
</dd>
<dt>Dutch BAC extension protocol</dt>
<dd>The complete protocol as presented by Rene Klein Lankhorst, kindly provided by Sander Peters [<a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/STC_protocol.doc">doc</a> | <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2006_docs/STC_protocol.doc">pdf</a>]</dd>
</dl>
EOHTML
			.info_section_html(title => 'SOL 2005 meeting',
					   subtitle => 'Wed, Sep 28, 2005',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt>
<dd>Ischia, Italy</dd>
<dt>Agenda</dt>
<dd><a href="http://www.solanaceae2005.org/">Link</a></dd>
<dt>Progress Reports</dt>
<dd>
Intro: Lukas Mueller <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2005_docs/SOL2005_Italy_intro.sxi">[sxi]</a><br />
Chromosome 1: Lukas Mueller
 <a href="/static_content/solanaceae-project/sol-bioinformatics/sol2005_docs/SOL2005_Sequencing.sxi">[sxi]</a>
<br />

Chromosome 2:
<a href="/static_content/solanaceae-project/sol-bioinformatics/sol2005_docs/SOL-Cheol-Goo-Hur-0928-annotation-final.ppt">[ppt]</a><br />

Chromosome 3: Eileen Wang
<a href="/static_content/solanaceae-project/sol-bioinformatics/sol2005_docs/chromosome_3_update.ppt">[ppt]</a><br />

Chromosome 4: Christine Nicholson
<a href="/static_content/solanaceae-project/sol-bioinformatics/sol2005_docs/Chrom_4_Ischia_Sep2005.ppt">[ppt]</a><br />

Chromosome 5: Jiten Khurana
<a href="/static_content/solanaceae-project/sol-bioinformatics/sol2005_docs/Khurana-SOL_Ischia05.ppt">[ppt]</a><br />

Chromosome 6: Rene Klein-Lankhorst
<a href="/static_content/solanaceae-project/sol-bioinformatics/sol2005_docs/SOL_lezing_italie_september_2005_part1.ppt">[ppt-part1]</a> |
<a href="/static_content/solanaceae-project/sol-bioinformatics/sol2005_docs/SOL_lezing_italie_september_2005_part2.ppt">[ppt-part2]</a><br />

Chromosome 7: Farid Regad
<br />

Chromosome 8: Satoshi Tabata
<br />

Chromosome 9: No presentation (only recently funded)
<br />

Chromosome 12: Mara Ercolano
<a href="/static_content/solanaceae-project/sol-bioinformatics/sol2005_docs/Mara_Ercolano_Italy.ppt">[ppt]</a><br />

</dd>
<dt>Key conclusions</dt>
<dd>
	<ul style="padding: 0">
		<li>Evidence presented indicates that a number of gene prediction programs tested with different matrices don\'t work reliably on tomato genomic sequence. It is therefore necessary to calibrate them for use with tomato. A training/test set will be developed for this purpose by MIPS/Ghent/U Naples.<br /><br /></li>
		<li>Extension BACs were found for all seed BACs on chromosome 6 and for more than half the seed BACs on chromosome 2. This shows that the approach is sound, but the lower success rate on chromosome 2 needs to be investigated.</li>
	</ul>
</dd>
</dl>
EOHTML

			.info_section_html(title => 'PAG meeting 2005',
					   subtitle => 'Sat, January 15, 2005, 1pm-6pm',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt><dd>Dover Room, Town and Country Hotel, San Diego, California, USA</dd>
<dt>Agenda</dt>  <dd><a href="/static_content/solanaceae-project/sol-bioinformatics/pag2005_docs/agenda.pdf">pdf</a></dd>
<dt>Progress Reports</dt>
<dd>
Chr 1 (USA): Lukas Mueller
  <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2005_docs/PAG_SOL_meeting.ppt">[ppt]</a><br />
Chr 2 (Korea): Doil Choi
  <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2005_docs/chr2_korea.ppt">[ppt]</a><br />
Chr 3 (China): not able to attend<br />
Chr 4 (UK): Christine Nicholson presentation [without slides]<br />
Chr 5 (India): Arun Sharma
  <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2005_docs/chr5_india.ppt">[ppt]</a><br />
Chr 6 (Netherlands): Rene Lank Kleinhorst<br />
Chr 7 (France): Farid Regad presentation [without slides]<br />
Chr 8 (Japan): Satoshi Tabata
  <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2005_docs/chr8_japan.ppt">[ppt]</a><br />
Chr 9 (Spain): (Funding in progress)<br />
Chr 12 (Italy): Maria Luisa Chiusano
  <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2005_docs/ItalyJanuary2005.ppt">[ppt]</a><br />
</dd>
<dt>Other presentations</dt>
<dd>
Lukas' Solanaceae workshop presentation
<a href="/static_content/solanaceae-project/sol-bioinformatics/pag2005_docs/PAG2005_Lukas.ppt">[ppt]</a><br />
Eileen's Overgo and BAC selection presentation
  <a href="/static_content/solanaceae-project/sol-bioinformatics/pag2005_docs/2005PAG_overgo.ppt">[ppt]</a><br />
</dd>
<dt>Minutes</dt>
<dd>Kindly provided by Robert Buels
<a href="/static_content/solanaceae-project/sol-bioinformatics/pag2005_docs/meeting_notes_Rob.txt">[txt]</a>
</dd>
</dl>
EOHTML

			.info_section_html(title => 'SOL 2004 meeting, Wageningen, The Netherlands',
					   subtitle => 'Sat, Sept 18, 2004, 9am-6pm',
					   is_subsection => 1,
					   contents => <<EOHTML)
<dl>
<dt>Location</dt><dd>Wageningen, The Netherlands</dd>
<dt>Presentations</dt>
<dd>
Sarah Butcher, GB <a href=
"/static_content/solanaceae-project/sol-bioinformatics/wageningen_docs/tomato_wageningen.ppt">[ppt]</a><br />Stephane
Rombauts, Belgium <a href=
"/static_content/solanaceae-project/sol-bioinformatics/wageningen_docs/Annotation_of_Tomato.ppt">[ppt]</a><br />David de
Koeyer, Canada <a href=
"/static_content/solanaceae-project/sol-bioinformatics/wageningen_docs/SOL_Bioinfo_de_Koeyer_final.ppt">[ppt]</a><br />
Silvana Grandillo, Italy <a href=
"/static_content/solanaceae-project/sol-bioinformatics/wageningen_docs/Wageningen.g.ppt">[ppt]</a><br /> Lukas Mueller, USA
<a href="/static_content/solanaceae-project/sol-bioinformatics/wageningen_docs/Wageningen_Lukas.ppt">[ppt]</a><br />Farid
Regad, France<br />Ralph van Berloo, NL<br />
</dd>
<dt>Key Conclusions</dt>
<dd>
  <dl>
  <dt>Data archiving, formats and access</dt>
  <dd><ul style="padding: 0">
      <li>Primary data needs to be archived and available to anyone</li>
      <li>Procedure/method/parameters used to generate a dataset need to
      be documented</li>
      <li>All working on a common datatype should agree on a common
      exchange format</li>
      </ul>
  </dd>
  <dt>Data Access</dt>
  <dd><ul style="padding: 0">
      <li>Central archive at SGN</li>
      <li>Method, how data arrives at SGN (upload, download, SMTP) agreed
      between SGN and other data source</li>
      <li>Data providers should implement the services required to
      integrate into the SOL platform/workgroup</li>
      </ul>
  </dd>
  <dt>Credit and Traceability</dt>
  <dd><ul style="padding: 0">
      <li>Keep original source information even if data travels through
      many hands</li>
      </ul>
  </dd>
  <dt>Annotation</dt>
  <dd>
     <ul style="padding: 0">
     <li>Sequences--&gt; a one-stop-shop</li>
     <li>Latest BAC, transcripts available</li>
     <li>FTP, maintain version and history of sequences \@ SGN</li>
     </ul>
  </dd>
  </dl>
</dd>
<dt>Minutes</dt>
<dd>
  <a href="/static_content/solanaceae-project/sol-bioinformatics/wageningen_docs/wageningen_minutes_sarah.txt">[from Sarah]</a><br />
  <a href="/static_content/solanaceae-project/sol-bioinformatics/wageningen_docs/wageningen_minutes_heiko.txt">[from Heiko]</a><br />
</dd>
</dl>
EOHTML
		       );

$page->footer();
