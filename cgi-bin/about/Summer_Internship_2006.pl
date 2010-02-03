use strict;
use CXGN::Page;
my $page=CXGN::Page->new('Summer_Internship_2006.html','Lukas');
$page->header('2006 Summer Interns');
print<<END_HEREDOC;

<div class="boxbgcolor2">

<h2 align="center">2006 Bioinformatics Summer Interns</h2>

<p>Four students participated in our Bioinformatics Summer Internship Program offered through the NSF-funded project entitled Sequence and annotation of the tomato euchromatin:  a framework for Solanceae comparative biology (http://www.sgn.cornell.edu/about/tomato_project_overview.pl). The internships provide opportunities in bioinformatics training for undergraduates and high school students.  Below are photographs of the 2006 summer interns along with descriptions of their projects.  For information on the internships, contact Dr. Joyce Van Eck (jv\@cornell.edu).</p>

<br />

<table summary="">

<tr><td><strong>Scott Bland</strong></td></tr>

<tr>
<td>
Scott Bland is a high school student at Ithaca High School. During his internship, he created Perl programs for use on the SGN website and worked on methods to predict orthology from gene trees. Currently, he is an undergradute at Stanford University.
</td>
</tr>

<tr><td>&nbsp;<br /></td></tr>

<tr><td><strong>Johnathon Schwarz</strong></td></tr>

<tr>
<td>Johnathon is a high school student at Ithaca High. He modified the SGN login system to use a database backend, ran the initial analyses to predict the SolCyc biochemical pathway databases, and installed a system to automatically monitor the SGN servers. 
</tr>

<tr><td>&nbsp;<br /></td></tr>

<tr><td><strong>Emily Hart</strong></td></tr>

<tr>
<td>Emily implemented several tools for the SGN website using Perl and relational databases. Currently, she is an undergraduate at Carnegie Mellon University.
</tr>

<tr><td><br /><strong>Adri Mills</strong></td></tr>

<tr>
<td>Adri, a veteran intern from 2005, liked the first internship so much she came back for a second one! She worked on features such as BLASTWatch, which lets users submit sequences which are then BLASTed once a week against the emerging tomato sequence and the users are alerted of new matches by email. Currently, Adri works as a programmer at SGN.
</tr>

<tr><td>&nbsp;<br /></td></tr>

<tr><td>
<center>
<img src="/static_content/sgn_photos/interns_2006/2006_summer_interns.jpg" />
<br />

<table><tr><td width="300">
The summer interns of the 2006 vintage: frtl: Johnathon Schwartz, Emily Hart and Scott Bland (Adri not pictured).
</td></tr></table>
</center>

</td></tr>
</table>

</div>
END_HEREDOC
$page->footer();
