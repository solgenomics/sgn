use strict;
use warnings;

use File::Temp qw(tempdir);
use HTML::LinkExtor;
use Test::More;
use Test::MockModule;
use Test::MockObject;
use URI;
use SGN::Controller::Cview;

# Exercise the actual controller and parse its links as HTML. Map rendering
# and database lookups are isolated so this regression runs with unit tests.
my %versions = (184 => 17, 185 => 17, 250 => 23);
my %current_versions = (17 => 185, 23 => 250);
my $tools = Test::MockModule->new('CXGN::Cview::Map::Tools');
$tools->mock(find_current_version => sub {
    my ($dbh, $id) = @_;
    return $current_versions{$id};
});
$tools->mock(find_map_id_with_version => sub {
    my ($dbh, $version) = @_;
    return $versions{$version} // $version;
});

my $map = Test::MockObject->new;
$map->mock(get_long_name => sub { 'Synthetic genetic map' });
$map->mock(get_short_name => sub { 'Synthetic' });
$map->mock(get_chromosome_names => sub { return ('1', '2') });
$map->mock(get_marker_count => sub { 3 });
$map->mock(get_map_stats => sub { '6 markers' });
$map->mock(get_abstract => sub { '' });
$map->mock(can_overlay => sub { 0 });
$map->mock(set_map_items => sub { return });
for my $parent (qw(parent1_stock_id parent1_stock_name parent2_stock_id parent2_stock_name)) {
    $map->mock("get_$parent" => sub { return });
}

my $factory = Test::MockObject->new;
$factory->mock(create => sub {
    my ($self, $args) = @_;
    return if $args->{map_version_id} eq '999';
    return $map;
});
my $factory_class = Test::MockModule->new('CXGN::Cview::MapFactory');
$factory_class->mock(new => sub { $factory });

my $overview = Test::MockObject->new;
$overview->mock(get_map => sub { $map });
$overview->mock(get_image_html => sub { '<img alt="Synthetic map" />' });
$overview->mock(get_markers_not_found => sub { return });
for my $method (qw(set_image_height set_image_width render_map hilite_marker)) {
    $overview->mock($method => sub { return });
}
my $overview_class = Test::MockModule->new('CXGN::Cview::MapOverviews::Generic');
$overview_class->mock(new => sub { $overview });

my $controller = Test::MockObject->new;
$controller->mock(data_is_private => sub { return });

for my $case (
    ['version only', { map_version_id => 184 }, 17, 184],
    ['map only', { map_id => 17 }, 17, 185],
    ['matching map and version', { map_id => 17, map_version_id => 184 }, 17, 184],
    ['conflicting map and version', { map_id => 23, map_version_id => 184 }, 17, 184],
    ['another map on the same chromosomes', { map_version_id => 250 }, 23, 250],
    ['non-database map', { map_version_id => 'p9' }, 'p9', 'p9'],
    ['missing map', { map_version_id => 999 }, undef, 999],
) {
    my ($name, $params, $expected_map, $expected_version) = @$case;
    subtest $name => sub {
        my $request = Test::MockObject->new;
        $request->mock(param => sub { $params->{$_[1]} });
        my $c = Test::MockObject->new;
        $c->{stash} = {
            basepath => tempdir(CLEANUP => 1),
            tempdir => 'cview',
            chr_url => '/cview/view_chromosome.pl',
        };
        $c->mock(stash => sub { $c->{stash} });
        $c->mock(req => sub { $request });
        $c->mock(forward => sub { return });

        SGN::Controller::Cview::map($controller, $c);

        if (!defined $expected_map) {
            is($c->stash->{template}, '/cview/map/missing.mas', 'missing map page is retained');
            ok(!exists $c->stash->{chromosome_stats}, 'missing map has no marker links');
            return;
        }

        is($c->stash->{map_id}, $expected_map, 'map ID belongs to the displayed version');
        is($c->stash->{map_version_id}, $expected_version, 'requested or current version is retained');
        is($c->stash->{template}, '/cview/map/index.mas', 'map overview is rendered');
        my $rows = $c->stash->{chromosome_stats};
        is(scalar @$rows, 2, 'both chromosome rows are present');
        for my $index (0 .. $#$rows) {
            my $parser = HTML::LinkExtor->new;
            $parser->parse($rows->[$index][1]);
            my @links = $parser->links;
            is(scalar @links, 1, 'marker count contains one link');
            my %attributes = @{$links[0]}[1 .. $#{$links[0]}];
            my $uri = URI->new($attributes{href});
            my %query = $uri->query_form;
            is($uri->path, '/search/markers/markersearch.pl', 'marker search endpoint is unchanged');
            is($query{w822_maps}, $expected_map, 'search is restricted to the displayed map');
            is($query{w822_chromos}, $index + 1, 'search is restricted to the selected chromosome');
            is($query{w822_mapped}, 'on', 'search still requires mapped markers');
        }
    };
}

done_testing();
