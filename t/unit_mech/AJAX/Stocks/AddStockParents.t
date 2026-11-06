use strict;
use warnings;
use utf8;
use lib 't/lib';
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use URI;
use LWP::UserAgent;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Stock;

my $f = SGN::Test::Fixture->new;
my $schema = $f->bcs_schema;
my $seed = $schema->resultset('Stock::Stock')->find({uniquename => 'test_accession1'});
my $at = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id;
my %types = map { $_ => SGN::Model::Cvterm->get_cvterm_row($schema, $_.'_parent', 'stock_relationship')->cvterm_id } qw(female male);
my @created;
sub stock {
    my ($name) = @_;
    my $row = $schema->resultset('Stock::Stock')->create({
        name => 'parents_http_'.$name, uniquename => 'parents_http_'.$name,
        type_id => $at, organism_id => $seed->organism_id,
    });
    push @created, $row;
    return $row;
}
my $female = stock('Мати A & B');
my $male = stock('father');
my $child = stock('child');
my $mech = Test::WWW::Mechanize->new;
my $url = 'http://localhost:3010/ajax/stock/add_stock_parents';
sub add_parents {
    my ($female_name, $male_name, $cross_type) = @_;
    $mech->post_ok($url, [stock_id => $child->stock_id, female_parent => $female_name,
        male_parent => $male_name, cross_type => $cross_type]);
    return decode_json($mech->content);
}
like(add_parents($female->uniquename, $male->uniquename, 'biparental')->{error}, qr/Log in/, 'anonymous POST cannot write');
$mech->post_ok('http://localhost:3010/brapi/v1/token', [username => 'janedoe', password => 'secretpw', grant_type => 'password']);
my $token = decode_json($mech->content)->{access_token};
$mech->get_ok($url.'?stock_id='.$child->stock_id);
like(decode_json($mech->content)->{error}, qr/POST/, 'new GET route does not write');
like(add_parents($female->uniquename, 'missing_http_parent', 'biparental')->{error}, qr/not found/, 'bad second name returns a JSON error');
is($schema->resultset('Stock::StockRelationship')->search({object_id => $child->stock_id})->count, 0, 'bad pair stores neither parent');
is_deeply(add_parents($female->uniquename, $male->uniquename, 'biparental'), {success => 1}, 'UTF-8 and ampersand name round-trips through form POST');
is_deeply(add_parents($female->uniquename, $male->uniquename, 'biparental'), {success => 1}, 'repeated POST is safe');
is($schema->resultset('Stock::StockRelationship')->search({object_id => $child->stock_id})->count, 2, 'no duplicate rows');
$mech->get_ok('http://localhost:3010/ajax/stock/parents?stock_id='.$child->stock_id);
my $parents = decode_json($mech->content);
is(scalar(@{$parents->{parents}}), 2, 'legacy parent list remains available');
is(scalar(@{$parents->{relationships}}), 2, 'new list exposes both roles');
my ($frow) = grep {$_->{parent_type} eq 'female'} @{$parents->{relationships}};
is($frow->{parent_name}, $female->uniquename, 'read endpoint preserves name characters');
is($frow->{cross_type}, 'biparental', 'read endpoint exposes existing type');
$mech->get_ok('http://localhost:3010/stock/'.$child->stock_id.'/datatables/parents');
is(decode_json($mech->content)->{data}[0][2], 'biparental', 'Parents HTTP table reads the child type');
for my $parent ($female, $male) {
    $mech->get_ok('http://localhost:3010/stock/'.$parent->stock_id.'/datatables/progenies');
    my ($r) = grep { $_->[3] eq $child->uniquename } @{decode_json($mech->content)->{data}};
    is($r->[1], 'biparental', 'maternal and paternal HTTP views show the same type');
}
$mech->get_ok('http://localhost:3010/brapi/v2/germplasm/'.$child->stock_id);
is(decode_json($mech->content)->{result}{breedingMethodDbId}, 'biparental', 'BrAPI germplasm read sees the stored type');

subtest 'real BrAPI germplasm POST and PUT retain female-only type storage' => sub {
    my $ua = LWP::UserAgent->new;
    $ua->default_header('Authorization' => 'Bearer '.$token);
    $ua->default_header('Content-Type' => 'application/json');
    my %payload = (germplasmName => 'parents_http_brapi_roundtrip',
        species => $seed->organism->species,
        pedigree => $female->uniquename.'/'.$male->uniquename, additionalInfo => {});
    my $response = $ua->post('http://localhost:3010/brapi/v2/germplasm', Content_Type => 'application/json', Content => encode_json([\%payload]));
    ok($response->is_success, 'BrAPI POST succeeds') or diag($response->status_line.' '.$response->decoded_content);
    my $row = $schema->resultset('Stock::Stock')->find({uniquename => $payload{germplasmName}});
    ok($row, 'BrAPI created the requested accession');
    return unless $row;
    push @created, $row;
    my $rels = $schema->resultset('Stock::StockRelationship')->search({object_id => $row->stock_id});
    is($rels->find({type_id => $types{female}})->value, 'biparental', 'POST preserves the existing BrAPI breeding-method convention');
    is($rels->find({type_id => $types{male}})->value, undef, 'POST writes no male cross type');
    $payload{pedigree} = $female->uniquename.'/test_accession2';
    $response = $ua->put('http://localhost:3010/brapi/v2/germplasm/'.$row->stock_id, Content_Type => 'application/json', Content => encode_json(\%payload));
    ok($response->is_success, 'BrAPI PUT succeeds') or diag($response->status_line.' '.$response->decoded_content);
    is($rels->find({type_id => $types{male}})->subject->uniquename, 'test_accession2', 'PUT replaces the requested father');
    is($rels->find({type_id => $types{male}})->value, undef, 'PUT also writes no male cross type');
    $mech->get_ok('http://localhost:3010/brapi/v2/pedigree?germplasmDbId='.$row->stock_id.'&includeParents=true&includeProgeny=false');
    my $tree = decode_json($mech->content)->{result}{data};
    my ($root) = grep {$_->{germplasmDbId} == $row->stock_id} @$tree;
    is(scalar(@{$root->{parents}}), 2, 'the pedigree viewer API still exposes both parent roles');
};

my $selfed = stock('selfed');
my $self_model = CXGN::Stock->new(schema => $schema, stock_id => $selfed->stock_id);
is($self_model->add_parents($male->uniquename, $male->uniquename, 'self'), undef, 'set up two roles for one parent');
my $remove_url = 'http://localhost:3010/ajax/stock/parent/remove';
$mech->post_ok($remove_url, [stock_id => $selfed->stock_id, parent_id => $male->stock_id]);
like(decode_json($mech->content)->{error}, qr/more than one role/, 'legacy removal refuses ambiguous selfed parent');
$mech->post_ok($remove_url, [stock_id => $selfed->stock_id, parent_id => $male->stock_id, parent_type => 'male']);
is_deeply(decode_json($mech->content), {success => 1}, 'remove the selected male role');
is($schema->resultset('Stock::StockRelationship')->search({object_id => $selfed->stock_id, type_id => $types{female}})->count, 1, 'female role survives');
$mech->post_ok($remove_url, [stock_id => $selfed->stock_id, parent_id => $male->stock_id, parent_type => 'other']);
like(decode_json($mech->content)->{error}, qr/female or male/, 'invalid role cannot delete a relationship');
$mech->post_ok($remove_url, [stock_id => $selfed->stock_id, parent_id => $male->stock_id]);
is_deeply(decode_json($mech->content), {success => 1}, 'legacy removal still works for a unique parent role');

my @ids = map { $_->stock_id } @created;
# BrAPI also records ownership in the phenome schema; remove owned test rows
# before deleting their stock so the foreign key remains satisfied.
$f->phenome_schema->resultset('StockOwner')->search({stock_id => {-in => \@ids}})->delete;
$schema->resultset('Stock::StockRelationship')->search({-or => [object_id => {-in => \@ids}, subject_id => {-in => \@ids}]})->delete;
$_->delete for reverse @created;
$f->clean_up_db;
done_testing;
