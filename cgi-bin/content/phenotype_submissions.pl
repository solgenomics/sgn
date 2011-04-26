use strict;
use CXGN::Page;
my $page=CXGN::Page->new('Phenotype submission format','Naama');
$page->header("SGN Phenotype Submission Guidelines", "SGN phenotype submission guidelines");

print<<END_HEREDOC;

<p>
SGN hosts a <a href="/search/direct_search.pl?search=phenotypes/">phenotype database</a> for displaying individual plant accessions scored for phenotypic attributes and more (links to genetic maps, QTLs, locus associations).<br>
Each accession is associated with a population, such as introgression lines, mutants, and mapping populations.<br>
    SGN users may upload <a href="/stock/0/new">new accessions or populations</a> using our web interface (you will be prompt to login first, and an SGN submitter account is required. Please <a href="mailto:sgn-feedback\@solgenomics.net">contact us</a> for for obtaining submitter privileges). <br/>
For large datasets we accept batch submissions of files with the following details:

<ul>
<li>Description of your population</li>
<li>Organism</li>
<li>contact person (We will create a new submitter account for you if you do not have one already)</li>
</ul>
<pre>
       <b>accession_id  description</b>
       accession1    free-text description of the phenotype
       accession2    description goes here
       .
       .
</pre>

We will upload your accessions and have the contact person assigned as the owner of all information.<br><br>

You may also submit any number of images for each one of your accession. Images can be added or deleted from the database at any time.
For a large number of images please <a href="mailto:sgn-feedback\@solgenomics.net">contact us</a> for mailing a CD or uploading your images to the SGN ftp site. If your filenames do not include the accession name (usually as a prefix, e.g. myAccession1_leaf.jpg) We also require a file with information on your images:

<pre>
  filename1   accession1
  filename2   accession1
  filename3   accession2
  .
  .
  .
</pre> 


If you have used <a href="/tools/onto/">'Solanaceae Phenotype'</a> terms for describing your accessions you can submit the annotation in the following format:

<pre> 
    accession1  SP000000X
    accession1  SP000000Y
    accession1  SP00000ZZ
    accession2  SP00000XY
    .
    .
    .
</pre>


<b>We will gladly add information and features to the phenotype database <a href="mailto:sgn-feedback\@solgenomics.net">upon request!</a> </b>

END_HEREDOC
$page->footer();
