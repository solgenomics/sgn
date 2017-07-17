
use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw | page_title_html blue_section_html |;

my $page = CXGN::Page->new();

$page->header();

my $page_title = page_title_html("SGN Locus and Phenotype Database");

print <<HTML;

$page_title
<br/>

<iframe src="//www.slideshare.net/slideshow/embed_code/key/rbDItCskr6kq5C" width="595" height="485" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC; border-width:1px; margin-bottom:5px; max-width: 100%;" allowfullscreen> </iframe> <div style="margin-bottom:5px"> <strong> <a href="//www.slideshare.net/nm249/sgn-community-annotation-tutorial" title="SGN community Annotation Tutorial" target="_blank">SGN community Annotation Tutorial</a> </strong> from <strong><a href="//www.slideshare.net/nm249" target="_blank">Naama Menda</a></strong> </div>



<br/>
<hr/>

<dt>What is community annotation?</dt>
<dd>
The concept of community annotation is a growing discipline for achieving participation of the research community in depositing up-to-date knowledge in biological databases.<br/>
One of the major efforts at SGN is linking Solanaceae phenotype information with the underlying genes, and subsequently the genome. As part of this goal, SGN has introduced a database for <a href="/search/direct_search.pl?search=loci">locus names and descriptors</a>, and a database for <a href="/search/direct_search.pl?search=phenotypes">phenotypes of natural and induced variation</a>. These two databases have web interfaces that allow cross references, associations with tomato gene models, and in-house curated information of sequences, literature, ontologies, gene networks, and  the <a href="http://solcyc.sgn.cornell.edu">Solanaceae biochemical pathways database</a>. All of our curator tools are open for online community annotation, through specially assigned "submitter" accounts.<br/><br>
 Currently the community database consists of 5,548 phenotyped accessions, and 5,739 curated loci, out of which more than 300 loci where contributed or annotated by more than 70 active submitters, creating a database that is truly community driven. 
</dd>

<dt>How do I begin annotating my favorite gene?</dt>
<ul>
<li> <b><a href= "/search/direct_search.pl?search=loci">Search for the locus</a></b>.
 You can get <b>editor privileges</b> for any locus in the database.<br/> Obtaining editor privileges is easy! Simply click on the '[Request editor privileges]' link from any locus page (next to the 'Locus editor' name), or <a href="mailto:sgn-feedback.sgn.cornell.edu">send us an email</a> and an SGN curator will create an account for you.</li> 

<li><b> Submit a new locus</b>. Your favorite Solanaceae locus is not found on SGN? We encourage you to <b>submit</b> information about genetic loci of the Solanaceae and related species <a href="/locus/0/view">here</a> (please notice that an <a href="/solpeople/new-account.pl">SGN account</a> is required for all data submissions). For large datasets, please <a href="mailto:sgn-feedback.sgn.cornell.edu">contact SGN</a>
</li>
</ul>
<br/>

<dd><img src="/documents/img/locus_edit.jpg" border="1"  width="80%" ></dd>

<br/>

<dt>Can I submit information without being the locus-editor?</dt>
<ul>
<li>You do not wish to be a locus editor, yet you want to <b>submit related information</b> such as publications or sequences?<br>
You may do so just by logging-in with your submitter account. <a href="/solpeople/new-account.pl">SGN account</a> can be created easily, but for submitting information we require a short validation step. Plese <a href="mailto:sgn-feedback.sgn.cornell.edu">email SGN</a> for obtaining permissions for accessing the community annotation features. 
</li>
</ul>
<br/>

<dd><img src="/documents/img/seq_submit.jpg" border="1"  width="80%"></dd>

<br/>

<dt>Can I post data without SGN submitter privileges?</dt>
<ul>
<li>At any time you may submit <b>user comments</b> to any locus or phenotype page. All you need is to log-in with your SGN user account.
User comments are posted at the bottom of each page.
</li>

</ul>


<br/>
<hr>
<br/>

<a name="phenotype"></a>
<dt>SGN phenotype database is also community-driven!</dt>
<dd>SGN hosts a collection of thousands Solanaceae <a href="../search/direct_search.pl?search=phenotypes">phenotyped accessions</a>, of several mapping and mutant populations. Phenotypes are linked to SGN loci whenever applicable. SGN submitters can edit any accession, upload images, and add cross-links to locus information.<br/></dd>

<dt>Submit Phenotype</dt>
<dd>New phenotypes and plant accessions can be submitted <a href="/stock/0/new">here</a>. For large datasets, please <a href="mailto:sgn-feedback.sgn.cornell.edu">contact SGN</a>.<br/>
Phenotype annotation works in a similar manner to locus annotation. Submitters of phenotypes are the owners of the accessions, and have full on-line editing privileges.<br />
For batch submission of phenotypes, you can send us a <a href= "/content/phenotype_submissions.pl">file with the information</a>, and images on a CD/DVD,  and we will upload the data for you.
</dd>

<dd><br/></dd>
<dd><img src="/documents/img/new_pheno.jpg" border="1" width="80%"></dd>

<br/>


<br/><hr/>

<dt>For detailed information on the loci and phenotypes community-editable databases please refer to the <a href="http://docs.google.com/Doc?id=ddhncntn_0cz2wj6">SGN submission guide</a>.</dt>
HTML


$page->footer();
