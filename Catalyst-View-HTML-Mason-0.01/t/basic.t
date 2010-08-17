use strict;
use warnings;
use Test::More;
use Test::Exception;

use FindBin;
use lib "$FindBin::Bin/lib";

use Catalyst::Test 'TestApp';

is(get('/'), "tiger\n" x 2, 'Basic rendering' );

is(get('/path_class'), "tiger\n" x 2, 'Path::Class objects as comp_root' );

is(get('/globals'),'Globals:grau,foo,bar,chef,ich', 'Multiple globals');

{
  my @warnings;
  $SIG{__WARN__} = sub{ push @warnings, @_ };
  is(get('/no_globals'),'Globals:', 'Multiple globals');
  is(scalar @warnings, 1, 'One warning issued for undef scalar');
  like($warnings[0], qr/uninitialized value.*maus/, 'Correct warning issued');
}

like(
  get('/xpackage_globals'),qr/error.*global.*maus.*horde.*stamm.*/si,
  'Prevented cross package access to globals'
);

is( get('/mixed_globals'), 'Globals:grau,me too!',
    'Paradigm clashes between sigil-less stash and globals' );

done_testing;
