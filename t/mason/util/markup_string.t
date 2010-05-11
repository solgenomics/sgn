use strict;
use warnings;

use SGN::Context;
use Bio::PrimarySeq;

use Test::More;

my $c = SGN::Context->instance;

my $test_string = 'fooish bar in the mailbox';
{ my $html = $c->render_mason('/util/markup_string.mas',
                              string => $test_string,
                             );

  like( $html, qr|^\s*$test_string\s*$|, 'outputs string and nothing else if no styles' );
}


{ my $html = $c->render_mason('/util/markup_string.mas',
                              string => $test_string,
                              styles => { foo => ['<span class="foo">','</span>'] },
                              regions => [ [ 'foo', 0, 3 ] ],
                             );

  like( $html, qr|$test_string|, 'test string is in single-region markup' );
  like( $html, qr|<span class=\\"foo\\">|, 'markup string is present' );
}


done_testing;

