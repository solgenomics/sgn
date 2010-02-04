use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html info_table_html/;
my $page=CXGN::Page->new('About the Sol Genomics Network','Robert Buels');
$page->add_style(text => <<EOS);
span.person_name {display: block}
span.person_position {font-size: smaller}
EOS
$page->header('About the Sol Genomics Network','About the Sol Genomics Network');

print<<END_HEREDOC;
<div class="indentedcontent">
<p>The Sol Genomics Network (SGN) is a clade oriented database dedicated to
the biology of the Solanaceae family which includes a large
number of closely related and many agronomically important
species such as tomato, potato, tobacco, eggplant, pepper,
and the ornamental <i>Petunia hybrida</i>.</p>

<p>SGN is part of the International Solanaceae Initiative (SOL), which
has the long-term goal of creating a network of resources and
information to address key questions in plant adaptation and
diversification.</p>

<p>A key problem of the post-genomic era is the linking of the phenome to the genome, and SGN allows to track and help discover new such linkages. 

</div>

END_HEREDOC

print info_section_html( title => 'Data', contents => <<EOHTML );
<dl>
<dt>ESTs</dt>
<dd>SGN houses EST collections for tomato, potato, pepper, eggplant and
petunia and corresponding unigene builds. EST sequence data and cDNA
clone resources greatly facilitate cloning strategies based on
sequence similarity, the study of syntenic relationships between
species in comparative mapping projects, and are essential for
microarray technology.
</dd>
<dt>Unigenes</dt>
<dd>SGN assembles and publishes unigene builds from these EST sequences.  For more information, see <a href="/methods/unigene/index.pl">Unigene Methods</a>.</dd>
<dt>Maps and Markers</dt>
<dd>SGN has genetic maps and a searchable catalog of markers for
tomato, potato, pepper, and eggplant.</dd>
<dt>Tomato Sequencing</dt>
<dd>SGN is the bioinformatics hub for the ongoing international project to
fully sequence the euchromatic portion of the tomato genome.  In this role,
we house:
  <ul style="margin-top: 0.5em">
    <li>a searchable catalog of tomato BACS</li>
    <li>more than 400,000 BAC end sequences from these BACs</li>
    <li>all BAC sequences used to assemble the tomato genome</li>
    <li>a <a href="/gbrowse/index.pl">Genome Browser</a> for the tomato genome</li>
  </ul>
</dd>
<dt>Tools</dt>
<dd>SGN makes available a wide range of web-based bioinformatics tools
for use by anyone, listed <a href="/tools/">here</a>.  Some of our
most popular tools include <a href="/tools/blast/">BLAST</a> searches,
the <a href="/tools/solcyc/">SolCyc biochemical pathways database</a>,
a <a href="/tools/caps_designer/caps_input.pl">CAPS experiment
designer</a>, an innovative
<a href="/tools/intron_detection/find_introns.pl">Intron detection
tool</a>, an advanced <a href="/tools/align_viewer/">Alignment Analyzer</a> and <a href="/tools/tree_browser/">browser for phylogenetic trees</a>.   </dd>

</dl>

<p>The data in SGN have been submitted by many different research
groups around the world which are acknowledged on the corresponding
pages on SGN.  If you have data you would like to submit for display
on SGN, please use the <a href="/tools/contact.pl">contact us</a> web
form, or email us at <a href="mailto:sgn-feedback\@sgn.cornell.edu">
sgn-feedback\@sgn.cornell.edu</a>.</p>

<p>For more information about SGN datasets, see the <a href= "/content/sgn_data.pl">SGN Data
Overview</a>. Entire datasets can also be downloaded from our <a href="ftp://ftp.sgn.cornell.edu">FTP site</a>.</p>
EOHTML

print info_section_html( title => 'SGN Tools and Processing', contents => <<EOHTML);
<ul style="margin: 0; padding-left: 1em">

   <li>We attempt to process all EST sequences
   directly from sequencing chromatograms using a custom
   pipeline developed at SGN. The sequences are assembled into unigenes
   using standard clustering software and in-house tools. A higher level of sequence
   quality is obtained when sequences are uniformly base-called and
   quality trimmed. Other software developed at SGN include the <a href="/cview/view_chromosome.pl">interactive comparative map viewer</a> for genetic and
   physical maps, the <a href="/tools/tree_browser/">Tree Browser</a> and the <a href="/tools/align_viewer">Alignment Analyzer</a>.</li>

   <li><a href="/methods/unigene/index.pl">Unigene Methods</a>
   including assembly process, builds, cluster, and validation</li>

</ul>
EOHTML

print info_section_html( title => 'SGN community-driven gene and phenotype database', contents => <<EOHTML);
<ul style="margin: 0; padding-left: 1em">

   <li>We have developed simple web interfaces for the SGN user-community to submit, annotate, and curate the Solanaceae locus and phenotype databases. Our goal is to share biological information, and have the experts in their field
   review existing data and submit information about their favorite genes and phenotypes.</li>

   <li>Please read more about the <a href="/phenome/index.pl">phenome database</a>
    and how to submit information to SGN.</li>

</ul>
EOHTML

print info_section_html( title => 'Funding', contents => <<EOHTML);

SGN gratefully acknowledges funding from the following funding sources:
<br /><br />
<table><tr>
<td width="100"><a href="http://www.nsf.gov/" class="footer"><img src="/documents/img/nsf_logo.png" border="0" /></a></td>
<td><b>National Science Foundation (USA)</b><br />
    <ul><li><a href="http://www.nsf.gov/awardsearch/showAward.do?AwardNumber=9872617">
    \#9872617</a> - Development of Tools for Tomato Functional Genomics</li>
    <li><a href="http://www.nsf.gov/awardsearch/showAward.do?AwardNumber=9975866">
    \#9975866</a> - Tools for Potato Structural and Functional Genomics</li>
    <li><a href="http://www.nsf.gov/awardsearch/showAward.do?AwardNumber=0116076">
    \#0116076</a> - Exploitation of Tomato as a Model for Comparative and Functional Genomics</li>
    <li><a href="http://www.nsf.gov/awardsearch/showAward.do?AwardNumber=0421634">
    \#0421634</a> - Sequence and Annotation of the Euchromatin of Tomato.</li>
    <li><a href="http://www.nsf.gov/awardsearch/showAward.do?AwardNumber=0606595">
    \#0606595</a> - Characterization of the Tomato Secretome Using Integrated Functional and Computational Strategies </li>
    </ul>
</td></tr>
<tr><td><a href="http://www.nifa.usda.gov/" class="footer"><img src="/documents/img/usda_nifa_v.jpg" border="0" /></a><br /><br /></td>
<td><b>USDA</b><br /><ul><li>USDA CSREES, grant \#2007-02777</li></ul></td>
</tr>
<tr><td>&nbsp;</td><td><b>Nestle Corporation</b><br />
SGN gratefully acknowledges a grant from the Nestle Corporation for generation, analysis and integration of Coffea canephora data.<br /><br />
</td></tr>
<tr><td><a href="http://www.bard-isus.com/" class="footer"><img src="/documents/img/BARD1.gif" border="0" /></a><br /><br /></td>
<td><b>BARD</b><br /><ul><li>BARD, grant \#FI­370­2005  Bioinformatic links of simple and complex phenotypes with Solanaceae genomes.</li></ul></td>
</tr>
</table>


</p>

EOHTML

    print info_section_html( title=>"Acknowledgments", contents=><<EOHTML );
<p>Special thanks to the <a href="http://cbsu.tc.cornell.edu">Cornell Biological Services Unit</a> for making their compute clusters available for some of our analyses.</p>
<p>Some data on SGN was obtained from EU-SOL projects. Special thanks to our colleagues at EU-SOL. <br />
<center>
<a href="http://www.eu-sol.net" class="footer"><img src="/documents/img/eusol_logo_small.jpg" /></a> <br />
</center>

EOHTML

print info_section_html( title => 'Selected Publications', contents => <<EOHTML);
	<ul>
        <li>

Mueller LA, Mills AA, Skwarecki B, Buels RM, Menda N, Tanksley SD (2008). The SGN comparative map viewer.  Bioinformatics. 2008 Feb 1;24(3):422-3.</li>
	<li>Mueller LA, Solow TH, Taylor N, Skwarecki B, Buels R, Binns J, Lin C, Wright MH, Ahrens R, Wang Y, Herbst EV, Keyder ER, Menda N, Zamir D, Tanksley SD. (2005)
	<i>The Sol Genomics Network. A Comparative Resource for Solanaceae Biology and Beyond.</i>
	<a href="http://www.plantphysiol.org/cgi/content/full/138/3/1310">Plant Physiol 138(3):1310-7</a>.</li>

    <li>Wu F, Mueller LA, Crouzillat D, Petiard V, Tanksley SD.	Combining bioinformatics and phylogenetics to identify large sets of single-copy orthologous genes (COSII) for comparative, evolutionary and systematic studies: a test case in the euasterid plant clade.
Genetics. 2006 Nov;174(3):1407-20. </li>

    <li>Lin C, Mueller LA, Mc Carthy J, Crouzillat D, Petiard V, Tanksley SD.
	Coffee and tomato share common gene repertoires as revealed by deep sequencing of seed and cherry transcripts.
Theor Appl Genet. 2005 Dec;112(1):114-30.</li>
	</ul>
EOHTML
sub person_image {
  my ($filebase,$name,$position) = @_;
  $name ||= '';
  $position ||= '';
  return <<EOHTML
  <a class="person" href="/static_content/sgn_photos/img/$filebase.jpg"><img src="/static_content/sgn_photos/img/${filebase}_small.jpg" alt="$name" /></a>
  <span class="person_name">$name</span>
  <span class="person_position">$position</span>
EOHTML
}
#given a 2-d array of person records (each an array of pic,name,and position),
#make a pretty formatted table
sub person_set {
  my @people = @_;
  return qq|<table width="100%">\n|
    .( join '',
       map {"<tr>\n$_\n</tr>\n"}
       map { my $colwidth = sprintf("%d",100/@$_);
	     ( join '',
	       map {$_ = person_image(@$_); qq|<td align="center" width="$colwidth%">\n$_</td>\n|}
	       @$_
	     )
	   }
       @people
     )
    ."</table>\n";
}
sub ul(@) { "<ul>\n".( join '', map {"<li>$_</li>\n"} @_ )."</ul>\n"; }

print info_section_html( title => 'Staff',
			 contents =>
			 info_section_html( title => 'Senior Staff',
					    is_subsection => 1,
					    contents => person_set 
					    ([ 
					       ['lukas','Lukas Mueller','Director'],
					       ['naama','Naama Menda','Postdoctoral Fellow'],
					       ['anuradha', 'Anuradha Pujar', 'Postdoctoral Fellow' ],
],
[
					       ['isaak', 'Isaak Tecle', 'Postdoctoral Fellow' ],
					       ['tom', 'Tom York', 'Postdoctoral Fellow' ],
                                               ['aureliano', 'Aureliano Bombarely', 'Postdoctoral Fellow' ]
					       ],
					     ),
					    )
			 .info_section_html( title => 'Bioinformatics Analysts &amp System Administration',
					     is_subsection => 1,
					     contents => person_set
					     ([ 
						['robert','Robert Buels'],
						['adri','Adri Mills'],
						['joseph','Joseph Gosselin'],
						],
					      ),
					     )

			 .info_section_html( title => 'Interns',
					     is_subsection => 1,
					     contents => 
					     ul(
                                                '<a href="/about/Summer_Internship_2008.pl">View summer 2008 intern photos &amp; projects</a>',
                                                '<a href="/outreach/index.pl#interns">Get information about our bioinformatics summer internship program</a>',            
                        ),
                                           )

			 .qq|<a href="/sgn_photos/index.pl"><strong>View more staff &amp; intern photos</strong></a>|
		       );
print info_section_html( title => 'Emeritus Staff',
			 contents =>
			 info_table_html( __multicol => 3, __border => 0,
					 'Bioinformatics Analysts' =>
					  ul(
                                             'Beth Skwarecki',
					     'Dean Eckstrom',
					     'Chris Carpita',
					     'Marty Kreuter',
					     'Chenwei Lin',
					     'John Binns',
					     'Teri Solow',
					     'Nicholas Taylor',
					     'Dan Ilut',
					     'Robert Ahrens',
					     'Mark Wright',
					    ),
					  'Interns' =>
					  ul(
                                             'Mallory Freeberg',
                                             'Carolyn Ochoa',
					     'Johnathon Schulz',
					     'Tim Jacobs',
					     'Sasha Naydich',
					     'Jessica Reuter',
					     'Matthew Crumb',	 
					     'Bob Albright',
					     'Emily Hart',
					     'Scott Bland',
					     'Amarachukwu Enemuo',
                                            ),
					  '&nbsp;' =>
					  ul(
                                             'Benjamin Cole',
					     'Caroline Nyenke',
					     'Tyler Simmons',
					     'Evan Herbst',
					     'Emil Keyder',
					     'Aseem Kohli',
					     'Igor Dolgalev',
					     'Miriam Wallace',
					     'Jay Gadgil',
					     'Jennifer Lee',
					    ),
					)
			 .<<EOHTML);
EOHTML

print info_section_html( title=> 'Computers',
			 contents => ul('<a href="/sgn_photos/index.pl">Photos of our server room</a>',
                                         '<a href="/about/temp.pl">Temperature in our server room</a>'));

print info_section_html( title => 'Other Pages', contents => <<EOHTML );
<ul>
<li><a href="/help/index.pl">SGN Help Home</a></li>
<li><a href="about_solanaceae.pl">Solanaceae family overview</a></li>
</ul>
EOHTML

$page->footer();
