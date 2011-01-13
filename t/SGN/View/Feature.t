package Test::SGN::View::Feature;
use strict;
use warnings;
use base 'Test::Class';

use Test::Class;
use lib 't/lib';
use SGN::Test::Data qw/create_test/;
use Test::More tests => 11;

use_ok('SGN::View::Feature', qw/
    feature_table related_stats cvterm_link
    feature_link organism_link
/ );

sub make_fixture : Test(setup) {
    my $self = shift;
    $self->{feature} = create_test('Sequence::Feature');
}

sub teardown : Test(teardown) {
    my $self = shift;
    # SGN::Test::Data objects self-destruct, don't clean them up here!
}

sub TEST_CVTERM_LINK : Tests {
    my $self = shift;
    my $f = $self->{feature};
    my ($id,$name) = ($f->type->cvterm_id,$f->type->name);
    $name =~ s/_/ /g;
    my $link = qq{<a href="/chado/cvterm.pl?cvterm_id=$id">$name</a>};
    is(cvterm_link($f->type),$link, 'cvterm link');
}

sub TEST_RELATED_STATS : Tests {
    my $self = shift;
    my $feature = create_test('Sequence::Feature');

    my $name1 = cvterm_link( $self->{feature}->type );
    my $name2 = cvterm_link( $feature->type );
    my $stats = related_stats([ $self->{feature}, $feature, $feature ]);
    is($stats->[0][1], $name1);
    is($stats->[0][0], 1);
    is($stats->[1][0], 2);
    is($stats->[1][1], $name2);
    is($stats->[2][0], 3);
    like($stats->[2][1] , qr'Total');
}

sub TEST_ORGANISM_LINK : Tests {
    my $self = shift;
    my $o             = create_test('Organism::Organism');
    my ($id,$species) = ($o->organism_id,$o->species);
    my $link          = qq{<a class="species_binomial" href="/chado/organism.pl?organism_id=$id">$species</a>};
    is(organism_link($o),$link, 'organism_link on a organism');
}

sub TEST_FEATURE_LINK : Tests {
    my $self = shift;
    my $f          = $self->{feature};
    my ($id,$name) = ($f->feature_id,$f->name);
    my $link       = qq{<a href="/feature/view/id/$id">$name</a>};
    is(feature_link($f),$link, 'feature_link on a feature');
    is(feature_link(),'<span class="ghosted">null</span>','feature_link returns a ghosted null when not given a feature');
}

Test::Class->runtests;
