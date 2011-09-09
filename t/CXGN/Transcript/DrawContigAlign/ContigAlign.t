use Test::More tests => 11;

use CXGN::Transcript::DrawContigAlign::ContigAlign;
use constant ContigAlign => 'CXGN::Transcript::DrawContigAlign::ContigAlign';

my $contigAlign = ContigAlign->new('foo', 'bar', 'baz', 1, 3060, 50, 40, 1);
is($contigAlign->sourceID, 'foo', 'ContigAlign sourceID');
is($contigAlign->sequenceID, 'bar', 'ContigAlign sequenceID');
is($contigAlign->strand, 'baz', 'ContigAlign strand');
is($contigAlign->startLoc, 1, 'ContigAlign startLoc');
is($contigAlign->endLoc, 3060, 'ContigAlign endLoc');
is($contigAlign->startTrim, 50, 'ContigAlign startTrim');
is($contigAlign->endTrim, 40, 'ContigAlign endTrim');
is($contigAlign->start, 51, 'ContigAlign start');
is($contigAlign->end, 3020, 'ContigAlign end');
ok($contigAlign->highlight, 'ContigAlign highlight');

my$contigAlign2 = ContigAlign->new('foo2', 'bar2', 'baz2', 1000, 9000, 2, 3, 0);
is($contigAlign->compare($contigAlign2), (50+1)-(1000+2), 'ContigAlign comparison');
