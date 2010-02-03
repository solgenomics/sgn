use strict;
use CXGN::Page;
my $page=CXGN::Page->new('Summer_Internship_2007.html','html2pl converter');
$page->header('2007 Summer Interns');
print<<END_HEREDOC;




<div class="boxbgcolor2">

<h2 align="center">2007 Bioinformatics Summer Interns</h2>

<p>Four students participated in our Bioinformatics Summer Internship Program offered through the NSF-funded project entitled Sequence and annotation of the tomato euchromatin:  a framework for Solanceae comparative biology (http://www.sgn.cornell.edu/about/tomato_project_overview.pl). The internships provide opportunities in bioinformatics training for undergraduates and high school students.  Below are photographs of the 2007 summer interns along with descriptions of their projects.  For information on the internships, contact Dr. Joyce Van Eck (jv\@cornell.edu).</p>

<br />

<table summary="">


<tr><td><strong>Jessica Reuter</strong></td></tr>

<tr>
<td><img src="/static_content/sgn_photos/interns_2007/jessica_reuter.jpg" /></td>
<td>Jessica Reuter is a bioinformatics student at Rochester Institute of Technology. During her internship, she created the SGN Image search, implemented an AJAX based ontology browser for the SGN website, where she developed both server end Perl programs and browser side JavaScript techniques, and designed XML documents formats used in the process.</td>
</tr>

<tr><td><br /><strong>Alexander Naydich</strong></td></tr>


<td width="220"><img src="/static_content/sgn_photos/interns_2007/sasha_naydich.jpg" /></td>
<td>
Alexander Naydich is a high school student at Ithaca High School. During his internship, he refactored object oriented Perl code and added features to the bulk download utility. In his second project, he worked on automatic annotation of Solanaceae gene loci using automated knowledge extraction from the literature data stored in the SGN database. 
</td>
</tr>

<tr><td><br /><strong>Matthew Crumb</strong></td></tr>

<tr>
<td><img src="/static_content/sgn_photos/interns_2007/matthew_crumb.jpg" /></td>
<td>Matthew Crumb is a high school student at Ithaca High School. During his internship, he refactored object oriented Perl code and added features to the bulk download utility. In his second project, he worked on automatic annotation of Solanaceae gene loci using automated knowledge extraction from the literature data stored in the SGN database.
</tr>

<tr><td><br /><strong>Tim Jacobs</strong></td></tr>

<tr>
<td><img src="/static_content/sgn_photos/interns_2007/tim_jacobs.jpg" /></td>
<td>Tim Jacobs is an undergraduate at University of Buffalo and implemented AJAX-based functionalities on the SGN website, dealing with associating different datatypes to each other using easy to use user interfaces for logged in users. He also implemented the AJAX aspects of the locus registry database.
</tr>


<tr><td>&nbsp;<br /></td></tr>


<tr><td>&nbsp;<br /></td></tr>


</table>

</div>
END_HEREDOC
$page->footer();
