use strict;
use warnings;

use CXGN::Page;
use CXGN::Tools::Onto;

my $p = CXGN::Page->new("Ontology Browser", "Lukas");

my $onto = CXGN::Tools::Onto->new($p);

$p->header("Ontology Browser", "Browse Ontologies");

$onto->browse();

$p->footer();
