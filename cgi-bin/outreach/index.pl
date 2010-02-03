

use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ blue_section_html page_title_html /;

my $page=CXGN::Page->new('SGN Educational Outreach','Joyce van Eck');

$page->header('SGN Educational Outreach');

my $title = page_title_html("SOL Outreach Activities and Materials");

my $overview = blue_section_html("Overview", <<OVERVIEW);

The purpose of outreach is to establish a link between the science community and students at all levels of education in order to foster interest in the sciences and expose students to scientific career paths. A specific mandate from funding agencies such as the National Science Foundation is to increase the participation of underrepresented groups in science.
<br /><br />
The US SOL outreach program focuses on Solanaceae biology and bioinformatics. The target audience is K-12 and college undergraduates, with a particular effort to engage underrepresented groups. Activies include presentations at elementary schools and associated after school programs, high schools, undergraduate classes, high school teacher curriculum workshops, and we provide hands-on laboratory activities. Bioinformatics training is taking place in the form of internships at SGN for undergraduate students.
<br /><br />
This page gives more information about the materials developed. Please contact us if you want to contribute materials. For more information, please contact the SOL outreach coordinator, <a href="mailto:jv27\@cornell.edu">Joyce Van Eck</a>.

OVERVIEW

my $activities = blue_section_html("Activities and Materials", <<ACTIVITIES);

<dl><dt><b>Potato Plant Growth and Develpment Activity</b></dt>
<dd>
<ul>
<li>Designed for high school biology curricula</li>
<li>A laboratory exercise, \"Tater Tots or Not?\", based on in vitro potato microtuber production was developed for use in the biology curriculum at the high school level.  Joyce Van Eck and an Ithaca High School biology teacher, Linda Knewstub, designed a laboratory class that requires collaboration, critical thinking, and scientific inquiry.  The exercise covers the following aspects of curriculum content: traits of living organisms (life functions), requirements of photosynthesis and respiration (cell energy), scientific method and experimental design, and cell division (mitosis, asexual reproduction, vegetative propagation, stem cells).</li>
<li>Resources: <a href="/static_content/outreach/Tater\ Tots\ or\ Not\ 06.doc">Student worksheet</a> (word format) | <a href="/static_content/outreach/Taters teacher version 06.doc">Teacher worksheet</a> (word format) | <a href="/static_content/outreach/Tissue\ culture\ procedures.ppt">Methods</a> (powerpoint format)</li>
</ul>
</dd>

<dt><b>The Solanaceae Family goes to school</b></dt>
<dd>
<ul>
<li>Designed for K-5</li>
<li>This educational outreach activity was designed for grades K-5 and has been done in elementary schools and after school programs.  The purpose of the activity is to teach children about members of the Solanaceae family, the concept of plant families, and diversity.  Various Solanaceae family members (tomatoes, potatoes, eggplants, peppers, and tomatillos) in all shapes, sizes, and colors are purchased at a local grocery store for the activity.  After cutting the vegetables open to look at the seeds or lack of seeds in the case of potatoes, the children taste the tomatoes, peppers, and tomatillos.  In addition to these vegetables, photographs of family members that are not found in local stores and flowers of the various Solanaceae are shown to the students.  After this activity, the children get to dress up the family members for a party.  At the end, a Word Find puzzle is given to the students to reinforce the terms that were discussed.  This Word Find, a list of supplies and slides are provided.</li>
<li>Resources: <a href="/static_content/outreach/sol\ word\ find.doc">Word Find puzzle</a> (word) | <a href="/static_content/outreach/Sol\ Family\ handout.doc">Handout</a> (word) | <a href="/static_content/outreach/solanaceae\ slides.ppt">Solanaceae slides</a> (powerpoint)</li>
<li><a href="/static_content/outreach/sol_family_coloring_book.pdf">Coloring Book</a></li>
</ul>
</dd>

<dt><b>User tutorial for SGN</b></dt>
<dd>
<ul>
<li>Designed for the high school and new user level.</li>
<li>Introduction to using SGN for high school students and new users, with hands on exercises.</li>
<li>Resources: <a href="/static_content/outreach/SGNHighSchoolTutuorial.doc">SGN tutorial</a></li>
<li>Kindly provided by Theresa Fulton.</li>
</ul>
</dd>

<dt><b>Sequencing puzzle</b></dt>
<dd><ul>
<li>The <a href="http://bti.cornell.edu/multimedia/puzzleComplete.html">Sequencing Puzzle</a> is an on-line interactive educational tool that explains genome sequencing using tomato as an example. It was developed by Dr. Joyce van Eck and Camilo Romero at <a href="http://bti.cornell.edu/">BTI</a>.</li>
</ul>
</dd>

<dt><b><a name="interns">Bioinformatics Summer Internships</a></b></dt>
<dd>
<ul>
<li>Available for college undergradutes</li>
<li>The bioinformatics summer internship accepts college undergraduates into the program. The internship is not available to graduate students. Students work at the Sol Genomics Network (SGN) for 8 - 10 weeks during the summer on their own bioinformatics-related projects. A staff member of SGN acts as project mentor for each student to help them learn the various programming skills necessary to develop their projects. As part of this internship, they also attend weekly seminars held at the Boyce Thompson Institute (BTI) that are given by plant scientists from BTI and Cornell.</li>
<ul>
    <li><a href="/about/Summer_Internship_2005.pl">2005 summer interns</a></li>
    <li><a href="/about/Summer_Internship_2006.pl">2006 summer interns</a></li>
    <li><a href="/about/Summer_Internship_2007.pl">2007 summer interns</a></li>
    <li><a href="/about/Summer_Internship_2008.pl">2008 summer interns</a></li>
</ul>
<li>You can find information about the 2010 summer internships <a href="/about/us_tomato_sequencing.pl#internships">here</a>.</li>
</ul>
</span>

</dd>


</dl>


ACTIVITIES

my $links = blue_section_html("Links", <<LINKS);

<ul>
<li><a href="http://www.plantgdb.org/PGROP/pgrop.php">Plant Genome Research Outreach Portal</a></li>
<li><a href="http://bti.cornell.edu/pgrp/">BTI-Cornell Plant Genome Outreach</a></li>
<li><a href="http://cibt.bio.cornell.edu">Cornell Institute for Biology Teachers</a></li> 
</ul>

LINKS

print $title;
print $overview;
print $activities;
print $links;

$page->footer();
