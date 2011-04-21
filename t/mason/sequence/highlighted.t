use strict;
use warnings;

use SGN::Context;
use Bio::PrimarySeq;

use Test::More;

# inject a mock stash method into SGN::Context
{ no warnings 'once'; *SGN::Context::stash = sub { {} }; }

my $c = SGN::Context->instance;

my $test_seq = Bio::PrimarySeq->new( -id => 'foo',
                                     -seq => 'ACGTGATGCTCTCTAGCATCTAGATCGTCATCGTAGC' x 1000,
                                    );

{ my $html = $c->render_mason('/sequence/highlighted.mas',
                              seq => $test_seq,
                             );

  like( $html, qr/foo/, 'contains seq name' );
}


{ my $html = $c->render_mason('/sequence/highlighted.mas',
                              seq => $test_seq,
                              highlight_coords => [[4,100],[30,50],[99,234]],
                              width => 20,
                             );

  like( $html, qr/foo/, 'contains seq name' );
  like( $html, qr/<span/, 'has some span tags' );
}



done_testing;
