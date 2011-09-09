use Test::More tests => 4;

use CXGN::Transcript::DrawContigAlign::Pane;
use constant Pane => 'CXGN::Transcript::DrawContigAlign::Pane';

my $pane = Pane->new(27, 70, 30, 400);
is($pane->north, 27,  'Pane north');
is($pane->south, 70,  'Pane south');
is($pane->west,  30,  'Pane west');
is($pane->east,  400, 'Pane east');
