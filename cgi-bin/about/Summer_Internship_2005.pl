use strict;
use CXGN::Page;
my $page=CXGN::Page->new('Summer_Internship_2005.html','html2pl converter');
$page->header('2005 Summer Interns');
print<<END_HEREDOC;




<div class="boxbgcolor2">

<h2 align="center">2005 Bioinformatics Summer Interns</h2>

<p>Five students participated in our Bioinformatics Summer Internship Program offered through the NSF-funded project entitled Sequence and annotation of the tomato euchromatin:  a framework for Solanceae comparative biology (http://www.sgn.cornell.edu/about/tomato_project_overview.pl). The internships provide opportunities in bioinformatics training for undergraduates and high school students.  Below are photographs of the 2005 summer interns along with descriptions of their projects.  For information on the internships, contact Dr. Joyce Van Eck (jv\@cornell.edu).</p>

<br />

<table summary="">

<tr><td><center><strong>Adri Anna Mills</strong></center></td></tr>

<tr>
<td><a href="/static_content/sgn_photos/img/pic17_large.jpg"><img src="/static_content/sgn_photos/img/pic17_small.jpg" alt="" /></a></td>
<td>Adri is an undergraduate at Cornell University, Ithaca, NY with a dual major in Computational Biology and Animal Science.  Her project in Dr. Mueller's group is to create automated tools to identify problems with the SGN website.  As a second project, Adri works on implementing MOBY services (http://www.biomoby.org/) at SGN.</td>
</tr>

<tr><td>&nbsp;<br /></td></tr>

<tr><td><center><strong>Amarachukwu Enemuo</strong></center></td></tr>

<tr>
<td><a href="/static_content/sgn_photos/img/pic21_large.jpg"><img src="/static_content/sgn_photos/img/pic21_small.jpg" alt="" /></a></td>
<td>Amara is majoring in Computer Engineering at The City College of New York, New York, NY.  Her project is in Dr. Lukas Mueller's group, and she is improving SGN functionality by adding gel images to the marker detail pages.  She is using SQL, Perl, web design, and image manipulation techniques in her project.</td>
</tr>

<tr><td>&nbsp;<br /></td></tr>

<tr><td><center><strong>Benjamin Cole</strong></center></td></tr>

<tr>
<td><a href="/static_content/sgn_photos/img/ben_cole_large.jpg"><img src="/static_content/sgn_photos/img/ben_cole_small.jpg" alt="" /></a></td>
<td>Ben is a Bioinformatics and Molecular Biology major at Rensselaer Polytechnic Institute, Troy, NY.  His internship is in Dr. Jim Giovannoni's lab, and Dr. Rob Alba is his project mentor.  Ben is working on a project related to pigmentation in tomato, which is an important component of fruit ripening, and the molecular mechanisms that govern this process are unknown.  He is using HPLC for time-series profiling of chlorophyll and carotenoid metabolites in tomato pericarp to characterize the function of photoreceptors and transcription factors.  His results yield new insights about the mechanism of phytochrome-regulated lycopene accumulation.  Resultant metabolite data will be integrated with existing transcriptome data (from identical tissues) to identify additional regulatory candidates for pigment metabolism.</td>
</tr>

<tr><td>&nbsp;<br /></td></tr>

<tr><td><center><strong>Caroline Nyenke</strong></center></td></tr>

<tr>
<td><a href="/static_content/sgn_photos/img/pic19_large.jpg"><img src="/static_content/sgn_photos/img/pic19_small.jpg" alt="" /></a></td>
<td>Caroline is majoring in Biological Science with an emphasis on molecular and cellular biology at Cornell University.  Her project in Dr. Mueller's group involves programming and web design.  She re-designed and implemented the new SGN toolbar.  In addition, she is developing a new bulk download facility for data from the tomato genome sequencing prject.</td>
</tr>

<tr><td>&nbsp;<br /></td></tr>

<tr><td><center><strong>Tyler Simmons</strong></center></td></tr>

<tr>
<td><a href="/static_content/sgn_photos/img/pic18_large.jpg"><img src="/static_content/sgn_photos/img/pic18_small.jpg" alt="" /></a></td>
<td>Tyler is a high school student from Newark Valley Senior High School in Newark Valley, NY.  He is also in Dr. Mueller's group, and he is creating webpages for the SGN website using HTML and web design.  He is actively learning to program using Perl.</td>
</tr>

</table>

</div>
END_HEREDOC
$page->footer();
