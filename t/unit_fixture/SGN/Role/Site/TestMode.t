use strict;
use warnings;

use Test::More;

my $config_1 = sub { +{
    foo  => 'bar',
    bee  => [qw( bal /bas bo )],
    quux => {
        zoom => ['/zow','zee'],
        noggin => '/fogbat',
        bunk => 'bonk',
        snorg => '/tees',
    },
    dog  => '/cat',
    'REL!!' => '/foo/shouldberel',
    '!!ABS' => '/bar/shouldbeabs',

    'Plugin::TestMode' => {
        reroot_conf => [
            '/quux/zoom',
            '/big/long/thing/that/does/not/exist',
            'zaz/zoz',
            'quux/bunk',
            '/quux/snorg',
            '(rel)REL!!',
            '(abs)!!ABS',
           ],
        test_data_dir => '/path/to/app/t/data',
    },
}};

my $rerooted_1 = {
  'Plugin::TestMode' => {
    'reroot_conf' => [
      '/quux/zoom',
      '/big/long/thing/that/does/not/exist',
      'zaz/zoz',
      'quux/bunk',
      '/quux/snorg',
      '(rel)REL!!',
      '(abs)!!ABS',
    ],
    'test_data_dir' => '/path/to/app/t/data'
  },

  'REL!!' => '/../../app/t/data/foo/shouldberel',
  '!!ABS' => '/path/to/app/t/data/bar/shouldbeabs',

  'bee' => [
    'bal',
    '/bas',
    'bo'
  ],
  'dog' => '/cat',
  'foo' => 'bar',
  'quux' => {
    'noggin' => '/fogbat',
    'zoom' => [
      '/path/to/app/t/data/zow',
      '../../app/t/data/zee'
    ],
    bunk => '../../app/t/data/bonk',
    snorg => '/path/to/app/t/data/tees',
  }
};


{
    local $ENV{MOCK_APP_TEST_MODE} = 1;
    my $c = mock_app->new( config => $config_1->() );
    $c->finalize_config;

    is_deeply( $c->config, $rerooted_1, 'test-mode configuration worked' )
        or diag 'actual config:', explain $c->config;
}


{
    local $ENV{MOCK_APP_TEST_MODE} = undef;
    my $c = mock_app->new;
    $c->config( $config_1->() );
    $c->finalize_config;

    is_deeply( $c->config, $config_1->(), 'non-test configuration worked' )
        or diag 'actual config:', explain $c->config;

}

done_testing;

###############

BEGIN {
    package mock_app;
    use Moose;
    use Test::MockObject;

    has 'config' => (
        is => 'rw',
        isa => 'HashRef',
       );

    with 'SGN::Role::Site::TestMode';

    my $engine = Test::MockObject->new;
    $engine->set_always( 'env', \%ENV );
    sub engine {
        $engine
    }

    sub finalize_config {};

    sub path_to {
        shift;
        return File::Spec->catfile(
            File::Spec->rootdir,
            qw( path to mock app ),
            @_
           );
    }
}

