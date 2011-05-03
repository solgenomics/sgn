use strict;
use warnings;
use Test::More;
use Data::Dumper;

use lib 't/lib';

use SGN::Test::WWW::Mechanize;

use_ok 'SGN::Controller::Organism';

my $mech = SGN::Test::WWW::Mechanize->new;

$mech->get_ok( '/organism/sol100/view' );
$mech->content_contains('SOL-100 Organisms');
$mech->content_contains('click on an organism name');
$mech->content_lacks('Add to Tree','not logged in, does not have a form for adding an organism');
$mech->while_logged_in({ user_type => 'curator' }, sub {
                           $mech->get_ok( '/organism/sol100/view' );
                           $mech->content_contains( 'Authorized user', 'now says authorized user' );
                           $mech->content_contains( 'Add a SOL-100 organism', 'now has an adding form' );

                       });

$mech->with_test_level( process => sub {
  require SGN;
  my $schema = SGN->dbic_schema('Bio::Chado::Schema','sgn_chado');
  my $controller = SGN->controller('Organism');

 SKIP: {

    my $organism = $schema->resultset('Organism::Organism')
            ->search({ species => 'Solanum lycopersicum' },
                     { rows => 1 }
                    )
            ->single;

    skip 'no organism to test on', 3 unless $organism;

    my $summary = $controller->species_data_summary_cache->thaw( $organism->organism_id );

    is( lc( $summary->{'Common Name'}), 'tomato', 'got common name from summary cache' );

 }

  my $sol100 = $controller->organism_sets->{sol100}{resultset};
  isa_ok( $sol100, 'DBIx::Class::ResultSet', 'got sol100 organism resultset' );

  # find an organism that is in the solanaceae but not part of sol100
  my $solanaceae = $controller->organism_sets->{Solanaceae}{resultset};
  isa_ok( $sol100, 'DBIx::Class::ResultSet', 'got solanaceae resultset' );

  my $test_organism = $solanaceae
      ->search({ 'organism.organism_id' => { -not_in => $sol100->get_column('organism_id')->as_query }},
               { rows => 1 }
              )
      ->single;
  diag "using test organism ".$test_organism->species;

 SKIP: {
      skip 'could not find an organism to test with', 0 unless $test_organism;

      $mech->while_logged_in({ user_type => 'curator' }, sub {
                                 $mech->submit_form_ok({
                                     form_name => 'sol100_add_form',
                                     fields    => { species => $test_organism->species },
                                 }, 'submitted add organism form');
                             });

      my $props = $test_organism->search_related('organismprops',{ 'type.name' => 'sol100'},{ join => 'type'} );
      is( $props->count, 1, 'test organism has been added to sol100' );
      is( $props->single->value, 1, 'has value one' );
      $props->delete;
  }

});


{ #test fetching an organism tree image

    $mech->get_ok( '/organism/sol100/view' );
    unless( $mech->content =~ /temporarily unavailable/ ) {
        $mech->get_ok( '/organism/tree/sol100/image' );
        is( $mech->content_type, 'image/png', 'got a png image from the image URL' );
    }
    $mech->get_ok( '/organism/tree/sol100/flush' );
    is( $mech->content_type, 'application/json', 'got a JSON response from the flush action' );
}


{ # test organism detail
    $mech->get_ok( '/organism/solanum_lycopersicum/view' );
    $mech->content_contains($_) for 'Solanum lycopersicum', 'tomato';

    $mech->get('/organism/nonexistent_organism/view');
    is( $mech->status, 404, 'got a 404 for nonexistent organism' );
}

done_testing;

