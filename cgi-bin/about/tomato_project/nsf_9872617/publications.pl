use strict;
use CXGN::Page;
my $page=CXGN::Page->new('publications.html','html2pl converter');
$page->header('Publications');
print<<END_HEREDOC;


  <h1>Publications derived from research funded entirely or
  partially by NSF-funded Tomato Genomics Project #9872617</h1>

  <p>D'Ascenzo, M., Mysore, K., He, X., Lyman, J., Subrahmanyam,
  T., Tuori, R., and Martin, G. (2000). Profiling of pathogen and
  elicitor-responsive genome-wide gene expression changes in tomato
  using cDNA microarrays. In preparation.</p>

  <p>Frary, A., Nesbitt, C., Grandillo, S., van der Knaap, E.,
  Cong, B., Liu, J., Meller, J., Elber, R., Alpert, K., and
  Tanksley, S. (2000) <em>fw2.2</em>: A quantitative trait locus key
  to the evolution of tomato fruit size. <em>Science</em>, in
  press.</p>

  <p>Giovannoni, J., Payton, P., Moore, S., White, R., and
  Vrebalov, J. (2000) Genetic control of fruit quality and
  prospects for nutrient modification. <em>HortScience</em>, invited
  manuscript in preparation.</p>

  <p>Ku, H., Vision, T., Liu, J., and Tanksley, S. (2000) Comparing
  sequenced segments of the tomato and <em>Arabidopsis</em> genomes:
  large-scale duplication followed by selective gene loss creates a
  network of synteny. <em>Proc. Natl. Acad. Sci.</em>, in
  press.</p>

  <h4>Book Chapters:</h4>

  <p>Moore, S., Payton, P. and Giovannoni, J. (2000) DNA
  microarrays for gene expression analysis. <u>Practical Approaches
  in Plant Molecular Biology.</u> (P. Gilmartin and C. Bowler, Eds)
  Oxford University Press, in press.</p>

  <h4>Databases/Websites</h4>

  <p><a href="/about/tomato_project/index.pl">Website for
  NSF-funded Tomato Genomics Project</a></p>

  <p><a href="http://www.tigr.org/tigr-scripts/tgi/T_index.cgi?species=tomato">TIGR TomatoGene
  index</a></p>

  <p><a href="/">Solanaceae Genome Network</a>
  (database for comparative genomics between Solanaceaous species
  and Arabidopsis</p>

END_HEREDOC
$page->footer();
