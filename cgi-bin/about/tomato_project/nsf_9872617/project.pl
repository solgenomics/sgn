use strict;
use CXGN::Page;
my $page=CXGN::Page->new('project.html','html2pl converter');
$page->header('Tomato Genome Project Description');
print<<END_HEREDOC;

  <h1>Project Background</h1>

  <p>Tomato has long served as a model system for plant genetics,
  development, pathology, and physiology, resulting in the
  accumulation of substantial information regarding the biology of
  this economically important organism. In recent years the most
  widely studied aspects of tomato biology include the development
  and ripening of their fleshy fruits and characterization of
  responses to infection by microbial pathogens. Although
  <em>Arabidopsis</em> has surpassed some plant systems as a model
  for basic plant biology research, the areas of fruit ripening and
  pathogen response continue to thrive using tomato as the system
  of choice. In the case of fruit development this is simply due to
  the fact that the developmental program which results in the
  dramatic expansion of ripening of carpels in tomato (and in many
  other economically and nutrionally important species) does not
  occur in <em>Arabidopsis</em>.</p>

  <p>With regard to plant defense, decades of applied and basic
  research on tomato have resulted in characterization of repsonses
  to numerous disease agents including bacteria, fungi, viruses,
  nematodes, and chewing insects. In many cases this research has
  led to the identification and genetic characterization of loci
  which confer general or pathogen-specific resistance. In
  addition, many experimental tools and features of tomato make it
  an excellent model system in its own right. These include:
  extensive germplasm collections, numerous natural, induced, and
  transgenic mutants and genetic variants, routine transformation
  technology, a dense RFLP map, numerous cDNA and genomic
  libraries, a small genome, relatively short life-cycle, and ease
  of growth and maintenace. The intense research effort in fruit
  biology and disease responses and the tools which make tomato an
  especially attractive model system have resulted in many
  important recent discoveries. Specific highlights which have a
  broad impact on the field of plant biology include control of
  gene expression by antisense/sense technology, functional
  characterization of numerous genes influencing fruit development
  and ripening, transgenic analysis of genes which impact
  susceptibility of responses to pathogen attack, and isolation of
  more disease resistance (R) genes than in any other plant
  species.<br /></p>

  <h1>Project Goals</h1>

  <p>The overall goal of the project includes the development of an
  integrated set of experimental tools for use in tomato functional
  genomics. The resources developed will be used to further expand
  our understanding of the molecular genetic events underlying
  fruit development and responses to pathogen infection, and will
  be made available to the research community for analysis of
  diverse plant biological phenomena.<br /></p>

  <h1>Specific Objectives</h1>

  <ol>
    <li>Development of a tomato EST database with
    emphasis on sequences expressed during fruit development and
    maturation, and in pathogen-challenged tissues.</li>

    <li>Genome-wide gene expression analysis during fruit
    development and ripening and under pathogen infection.</li>

    <li>Development of a tomato-arabidopsis synteny map which will
    be used by members of this group and made publicly available
    for target gene isolation, candidate gene identification, and
    analysis of dicot genome organization and evolution.</li>
  </ol>

    

END_HEREDOC
$page->footer();