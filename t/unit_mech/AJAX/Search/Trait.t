use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;

use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;

my $mech = Test::WWW::Mechanize->new;
my $response;

$mech->post_ok('http://localhost:3010/ajax/search/traits?length=5&start=1' );
$response = decode_json $mech->content;
print STDERR Dumper $response;

is_deeply($response, {'recordsFiltered' => 10206,'recordsTotal' => 10206,'data' => [['','<a href="/cvterm/68621/view">GO:0000148</a>','<a href="/cvterm/68621/view">1,3-beta-D-glucan synthase complex</a>','A protein complex that catalyzes the transfer of a glucose group from UDP-glucose to a 1,3-beta-D-glucan chain.','is_a','1,3-beta-D-glucan synthase complex','GO:0000148'],['','<a href="/cvterm/68241/view">GO:0008247</a>','<a href="/cvterm/68241/view">1-alkyl-2-acetylglycerophosphocholine esterase complex</a>','An enzyme complex composed of two catalytic alpha subunits, which form a catalytic dimer, and a non-catalytic, regulatory beta subunit; the catalytic dimer may be an alpha1/alpha1 or alpha2/alpha2 homodimer, or an alpha1/alpha2 heterodimer. Modulates the action of platelet-activating factor (PAF).','is_a','1-alkyl-2-acetylglycerophosphocholine esterase complex','GO:0008247'],['','<a href="/cvterm/70556/view">PO:0007601</a>','<a href="/cvterm/70556/view">1 flower meristem visible</a>','Stage of flower development marked by the emergence of the floral meristem on the flank of the inflorescence meristem.','is_a','1 flower meristem visible','PO:0007601'],['','<a href="/cvterm/70540/view">PO:0001051</a>','<a href="/cvterm/70540/view">1 leaf initiation stage</a>','The earliest histological evidence of leaf initiation, i.e, a change in the orientation of cell division both in the epidermis and in internal layers of the shoot meristem occurs at this stage (Poethig S, 1997, Plant Cell 9:1077-1087).','is_a','1 leaf initiation stage','PO:0001051'],['','<a href="/cvterm/70380/view">PO:0007112</a>','<a href="/cvterm/70380/view">1 main shoot growth</a>','The stage at which vegetative structures are being produced by SAM.','is_a','1 main shoot growth','PO:0007112']],'draw' => undef}, 'trait ajax search');


done_testing();
