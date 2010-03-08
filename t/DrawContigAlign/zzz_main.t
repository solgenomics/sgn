use strict;
use warnings;

use Test::More tests => 7;

use CXGN::Transcript::DrawContigAlign;
use constant DrawContigAlign => 'CXGN::Transcript::DrawContigAlign';

#Tests the rounding
my $drawContig = DrawContigAlign->new;
is($drawContig->round(3.2), 3, 'DrawContigAlign round 3.2');
is($drawContig->round(6.5), 7, 'DrawContigAlign round 6.5');
is($drawContig->roundTo(430, 100), 500, 'DrawContigAlign roundTo 100');

#Creates and tests to see if the image and map files exist (smaller example)
my $drawContig2 = DrawContigAlign->new;
$drawContig2->addAlignment('SourceID 1', 'SequenceID 1', '-', 0, 490, 20, 10, 1);
$drawContig2->addAlignment('SourceID 2', 'SequenceID 2', '+', 320, 1062, 0, 0, 0);
$drawContig2->addAlignment('SourceID 3', 'SequenceID 3', '+', 440, 598, 0, 8, 1);
$drawContig2->addAlignment('SourceID 4', 'SequenceID 4', '-', 110, 220, 5, 5, 0);
$drawContig2->writeImageToFile('Turkeydog2.png', 'Turkeydog2.map', 'Link Basename2', 'This Image Thinger2');
open my $TURKEYDOG2, '<Turkeydog2.png';
ok($TURKEYDOG2, 'DrawContigAlign created image');
open my $TURKEYDOGMAP2, '<Turkeydog2.map';
ok($TURKEYDOGMAP2, 'DrawContigAlign created map');

#Creates and tests to see if the image and map files exist (larger example)
$drawContig->addAlignment('SourceID 1', 'SequenceID 1', '-', 0, 490, 20, 10, 1);
$drawContig->addAlignment('SourceID 2', 'SequenceID 2', '+', 320, 1062, 0, 0, 0);
$drawContig->addAlignment('SourceID 3', 'SequenceID 3', '+', 440, 598, 0, 8, 1);
$drawContig->addAlignment('SourceID 4', 'SequenceID 4', '-', 110, 220, 5, 5, 0) for(0..100);
$drawContig->writeImageToFile('Turkeydog.png', 'Turkeydog.map', 'Link Basename1', 'This Image Thinger');
open my $TURKEYDOG1, '<Turkeydog.png';
ok(defined($TURKEYDOG1), 'DrawContigAlign created image');
open my $TURKEYDOGMAP1, '<Turkeydog.map';
ok(defined($TURKEYDOGMAP1), 'DrawContigAlign created map');

unlink glob 'Turkeydog{,2}.{png,map}';

