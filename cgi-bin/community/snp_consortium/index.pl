use strict;
use CXGN::Page;
my $page=CXGN::Page->new('index.html','html2pl converter');
$page->header('USDA Public SNP Consortium');
print<<END_HEREDOC;

<h4>Public Tomato SNP Consortium</h4>

This page has been removed. 

For questions about the SNP consortium, please write to the <a href="http://rubisco.sgn.cornell.edu/mailman/listinfo/public-snp">SNP mailing list</a>.

END_HEREDOC



#   <center>
    

#     <h4>Public Tomato SNP Consortium</h4>

#      <center><img src=
#     "/static_content/community/snp_consortium/CTRI_Main_Logo_small.jpg" alt="" />&nbsp;&nbsp;&nbsp;&nbsp;<img src=
#     "/static_content/community/snp_consortium/USDARSlogo_small.jpg" alt="" /></center>

# <br />
#     <p>The California Tomato Research Institute, Inc. (<a href=
#     "http://www.tomatonet.org/ctri.htm">CTRI</a>) would like to
#     announce the formation of the Tomato Public SNP Consortium to
#     facilitate more rapid development of single nucleotide
#     polymorphisms (SNPs) predicted at USDA-ARS PGRU.</p>

#     <p>The CTRI is well known in the California processing tomato
#     industry as a facilitator and sponsor of a wide array of crop
#     improvement projects. A private, non-profit association
#     funded entirely by voluntary grower contributions, CTRI
#     annually supports public and private researchers. CTRI is
#     organized as a US IRS 501-C-5 corporation, allowing us to fund
#     USDA research from contributions such as this consortium would
#     generate. This effort advances our grower members
#     interest to enhance the ability of breeders to provide improved
#     varieties to the industry. CTRI has agreed to serve as
#     lead for the Tomato Public SNP Consortium and serve as the
#     non-technical, business facilitator of the group. We
#     propose to contribute all services and charge no fees for the
#     organization and administration of the consortium. Our
#     organization is audited annually and financial records will be
#     made available.</p>

#     <p>Members of the consortium would gain a close working
#     relationship with the project and all the benefits that accrue
#     to that level of involvement, such as pre-publication access to
#     data. As a public agency, USDA will publish final results
#     of the work once it is completed and reviewed.<br />
#     <br />
#     We will need a critical mass of companies willing to pledge
#     contributions to initiate the consortium, and once that is
#     achieved membership dues will be spread equally among all
#     members. I would propose two annual payments to complete
#     the project over the two year project period. Companies
#     wishing to join the consortium after the start date will be
#     required to provide the same dues as each initial member.
#     Surplus funds at the end of the project will either be refunded
#     to the members or applied to a proposal of their interest. We
#     would also be happy to entertain the possibility for public
#     tomato breeders to join and contribute scientifically rather
#     than financially.</p>

# <br />

# <dl>
#     <dt>Pre-Proposal:</dt>

#     <dd><br />The USDA, ARS Plant Genetic Resources Unit (<a href=
#     "http://www.ars.usda.gov/Main/site_main.htm?modecode=19-10-05-00">PGRU</a>) in Geneva, NY has
#     identified 764 cultivated tomato Unigenes that contain
#     predicted Single Nucleotide Polymorphisms (SNPs). We have
#     resequenced 85 independent amplicons from the set and roughly
#     25\% showed cultivar-specific polymorphisms. We propose to
#     develop and test the remaining 679 Unigenes with predicted SNPs
#     in a collaborative effort. View the pre-proposal: [<a href=
#     "/static_content/community/snp_consortium/Labate_tomato_tech.pdf">PDF</a>][<a href="Labate_tomato_tech.pl">html</a>]</dd>

#     <dt><br />Participants:</dt>

#     <dd><br /><a href=
#     "http://www.westernseed.nl/menu.asp?language=1">Western
#     Seed</a> would like to participate in the public tomato SNP
#     consortium with the condition that at least six companies
#     (including Western Seed) will join.</dd>

#     <dt><br />Mailing List:</dt>

#     <dd><br />If you are interested in receiving emails about the
#     consortium, sign up on the mailing list <a href=
#     "http://rubisco.sgn.cornell.edu/mailman/listinfo/public-snp">here</a>
#     . Scientific questions regarding the project proposal can be
#     publically discussed on the mailing list.</dd>

#     <dt><br />For organizational issues or general questions about the
#     Public Tomato SNP Consortium, please contact:</dt>

#     <dd><br /><a href="mailto:chuck\@tomatonet.org">Chuck J.
#     Rivara</a><br />
#     Director, <a href=
#     "http://www.tomatonet.org/ctri.htm">California Tomato Research
#     Institute, Inc.</a><br />
#     209-838-1594<br />
#     Fax 209-838-1595</dd>
# </dl>

#   </center>
# END_HEREDOC


$page->footer();
