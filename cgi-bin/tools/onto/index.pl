use strict;
use warnings;

use CXGN::Page;

use CXGN::Page::FormattingHelpers qw/ info_section_html /;
use CatalystX::GlobalContext qw( $c );
my $p = CXGN::Page->new("Ontology Browser", "Lukas");
$p->header("Ontology Browser", "Browse Ontologies");

print info_section_html(
    title    => 'Ontology browser',
    contents => $c->render_mason("/ontology/browser.mas"),
   );

$p->footer();
