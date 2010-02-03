use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('NSF_SPONSORED TOMATO GENOMICS PROJECT');
print<<END_HEREDOC;

  <center>
    <h1>Welcome to the NSF-Funded Tomato Genomics Project</h1>

    <h3>Development of tools for tomato
    functional genomics:<br />
    application to fruit development, responses to pathogens, and
    genomic synteny with <em>Arabidopsis</em></h3>

    <img src="/documents/help/about/tomato_project/nsf_9872617/../nsf-logo3.gif" width="91" height="100" border="0" alt="" />

  <hr />
</center>

  <p>Welcome to the information pages for the Tomato Genomics
  Project (#9872617). This project is funded by the <a href=
  "http://www.nsf.gov/funding/pgm_summ.jsp?pims_id=5338">National
  Science Foundation Plant Genome Research Program</a>.
  The purpose of these pages is to provide information on the goals
  of the project, the P.I's involved in the project, progress
  reports and public resources developed as part of this project.
  Also provided are links to related sites/databases concerning
  tomato genetics/genomics. If you have suggestions/comments about
  this site or the Tomato Genomics Project, please e-mail <a href=
  "mailto:sdt4\@cornell.edu">Steve
  Tanklsley</a>.</p>

<p>For more details, click on any of the topics below.</p>
<ul>
        <li><a href="project.pl">Project Goals</a></li>
        <li><a href="http://ted.bti.cornell.edu/">Expression Database</a></li>
        <li><a href="http://bti.cornell.edu/CGEP/CGEP.html">Microarrays</a></li>
        <li><a href="/maps/tomato_arabidopsis/index.pl">Tomato-Arabidopsis Synteny</a></li>
        <li><a href="progress.pl">Original Progress Reports</a></li>
        <li><a href="members.pl">Members of Advisory Group</a></li>
        <li><a href="websites.pl">Links to Related Websites</a></li>
        <li><a href="publications.pl">Publications</a></li>	
</ul>

<br />

    

END_HEREDOC
$page->footer();