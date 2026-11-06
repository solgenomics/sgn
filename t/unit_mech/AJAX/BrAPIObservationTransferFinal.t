use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use JSON::XS;
use SGN::Test::Fixture;
use SGN::Test::OwnedTrialCleanup;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialCreate;
my $f=SGN::Test::Fixture->new;
my $schema=$f->bcs_schema;
my $base='http://localhost:3010';
my $m=Test::WWW::Mechanize->new;
$m->post_ok("$base/brapi/v1/token",[username=>'janedoe',password=>'secretpw',grant_type=>'password'],'fixture login');
my $ua=LWP::UserAgent->new(timeout=>60);
$ua->default_header('Content-Type'=>'application/json');
$ua->default_header('Authorization'=>'Bearer '.decode_json($m->content)->{access_token});

my $tag = 'observation_transfer_'.$$.'_'.time();
my $owned = SGN::Test::OwnedTrialCleanup->new(
    schema => $schema, label => 'transfer',
    trial_name => $tag.'_trial', stock_names => [map { $tag.'_plot'.$_ } 1..15],
    %{SGN::Test::OwnedTrialCleanup->cutoffs($schema)},
);

# Own all units: successful uploads and rejected requests cannot contaminate
# test_trial's original layout, measurements, or file history.
my %design = map { $_ => {
    stock_name => 'test_accession1', plot_name => $tag.'_plot'.$_,
    plot_number => $_, block_number => 1, rep_number => 1,
    row_number => 1, col_number => $_,
} } 1..15;
my $saved = CXGN::Trial::TrialCreate->new({
    chado_schema => $schema, dbh => $f->dbh, owner_id => 41,
    design => \%design, program => 'test', trial_year => '2026',
    trial_description => 'Disposable observation transfer regression',
    trial_location => 'test_location', trial_name => $tag.'_trial',
    design_type => 'CRD', operator => 'janedoe',
})->save_trial;
ok($saved->{trial_id}, 'own observation transfer trial created') or BAIL_OUT(encode_json($saved));
$owned->checkpoint('after_creation');
my %plot = map { $_ => $schema->resultset('Stock::Stock')->find({uniquename=>$tag.'_plot'.$_})->stock_id } 1..15;
my $trait=70666;
sub count_values {my($id)=@_; return($schema->storage->dbh->selectrow_array('SELECT count(*) FROM nd_experiment_stock nes JOIN nd_experiment_phenotype nep USING(nd_experiment_id) JOIN phenotype p USING(phenotype_id) WHERE nes.stock_id=? AND p.cvalue_id=?',undef,$id,$trait))[0]}
sub send_values {
 my($version,$values)=@_;
 my @observations=map {{observationUnitDbId=>"$_->[0]",observationVariableDbId=>"$trait",value=>$_->[1],observationTimeStamp=>'2026-11-02T10:00:00Z'}} @$values;
 my($path,$body);
 if($version eq 'v1'){$path='/brapi/v1/phenotypes';$body={data=>[map {{observationUnitDbId=>$_->{observationUnitDbId},observations=>[$_]}} @observations]};}
 else {$path='/brapi/v2/observations';$body=\@observations;}
 my $r=$ua->post($base.$path,Content=>encode_json($body));
 my $json=eval {decode_json($r->decoded_content)}||{};
 return($r,$json);
}
for my $version(qw(v1 v2)) {
 subtest "$version rejects an invalid numeric value without partial writes"=>sub {
  my @ids=$version eq 'v1' ? @plot{1,2} : @plot{3,4};my @before=map {count_values($_)} @ids;
  my($r,$j)=send_values($version,[[$ids[0],'15'],[$ids[1],'audit_not_a_number']]);
  my @errors=grep {($_->{messageType}//'') eq 'ERROR'} @{$j->{metadata}->{status}||[]};
  ok(!$r->is_success||@errors,'invalid input reported as error');
  is_deeply([map {count_values($_)} @ids],\@before,'neither valid nor invalid row stored');
  diag('HTTP '.$r->code.' errors: '.join(' ',map {$_->{message}//''} @errors));
 };
}
my %operator;
for my $case(['v1',13],['v2',14]) {
 my($version,$n)=@$case;
 subtest "$version stores valid data once and identifies its collector"=>sub {
  my $id=$plot{$n};my $before=count_values($id);
  my($r,$j)=send_values($version,[[$id,'15']]);
  ok($r->is_success,'valid upload accepted') or diag($r->decoded_content);
  $owned->checkpoint('after_http_store');
  is(count_values($id),$before+1,'one value actually stored');
  ($operator{$version})=$schema->storage->dbh->selectrow_array('SELECT p.operator FROM nd_experiment_stock nes JOIN nd_experiment_phenotype nep USING(nd_experiment_id) JOIN phenotype p USING(phenotype_id) WHERE nes.stock_id=? AND p.cvalue_id=? ORDER BY p.phenotype_id DESC LIMIT 1',undef,$id,$trait);
  is($operator{$version},'janedoe','omitted collector falls back to username');
  ($r,$j)=send_values($version,[[$id,'15']]);
  ok($r->is_success || $r->code==400,'retry returns a controlled outcome'); diag('retry HTTP '.$r->code);
  is(count_values($id),$before+1,'retry does not duplicate the measurement');
 };
}
is($operator{v1},$operator{v2},'v1 and v2 persist the same collector identity');
subtest 'A stored ID crosses versions without losing metadata or changing units'=>sub {
 my ($id)=$schema->storage->dbh->selectrow_array('SELECT p.phenotype_id FROM nd_experiment_stock nes JOIN nd_experiment_phenotype nep USING(nd_experiment_id) JOIN phenotype p USING(phenotype_id) WHERE nes.stock_id=? AND p.cvalue_id=? ORDER BY p.phenotype_id DESC LIMIT 1',undef,$plot{13},$trait);
 ok($id,'positive upload supplied a real persistent ID');return if !$id;
 my $payload={observationUnitDbId=>"$plot{13}",observationVariableDbId=>"$trait",value=>'15',collector=>'0',observationTimeStamp=>'2026-11-02T13:00:00+02:00'};
 my $r=$ua->put("$base/brapi/v1/observations/$id",Content=>encode_json($payload));
 is($r->code,200,'advertised v1 single-ID PUT updates a stored measurement') or diag($r->decoded_content);
 for my $version(qw(v1 v2)) {
  $r=$ua->get("$base/brapi/$version/observations/$id");is($r->code,200,"$version reads the same ID");
  my $value=eval{decode_json($r->decoded_content)->{result}}||{};
  is_deeply([@{$value}{qw(observationDbId observationUnitDbId observationVariableDbId value collector observationTimeStamp)}],["$id","$plot{13}","$trait",'15','0','2026-11-02T11:00:00Z'],"$version readback preserves identity, zero collector and UTC instant");
  $r=$ua->get("$base/brapi/$version/observations?observationDbIds=$id&pageSize=100");
  my $json=eval{decode_json($r->decoded_content)}||{};
  is_deeply([map{$_->{observationDbId}} @{$json->{result}{data}||[]}],["$id"],"$version plural ID query reaches the backend filter");
 }
 $r=$ua->put("$base/brapi/v2/observations/$id",Content=>encode_json({%$payload,observationUnitDbId=>"$plot{14}",value=>'98'}));
 is($r->code,400,'addressed ID cannot be redirected to another unit');
 my ($value)=$schema->storage->dbh->selectrow_array('SELECT value FROM phenotype WHERE phenotype_id=?',undef,$id);is($value,'15','invalid cross-unit PUT leaves the stored value intact');
 $r=$ua->put("$base/brapi/v2/observations/$id",Content=>encode_json({observationUnitDbId=>"$plot{13}",observationVariableDbId=>"$trait",value=>'16'}));
 is($r->code,200,'v2 sparse PUT updates the same ID') or diag($r->decoded_content);
 my $stored=$schema->storage->dbh->selectrow_hashref('SELECT value,operator,collect_date FROM phenotype WHERE phenotype_id=?',undef,$id);
 is_deeply([@{$stored}{qw(value operator collect_date)}],['16','0','2026-11-02 11:00:00'],'sparse cross-version update preserves omitted metadata');
 $r=$ua->put("$base/brapi/v2/observations/$id",Content=>encode_json({observationUnitDbId=>"$plot{13}",observationVariableDbId=>"$trait",value=>'17',externalReferences=>0}));
 is($r->code,400,'falsy malformed references are refused before any write');
 ($value)=$schema->storage->dbh->selectrow_array('SELECT value FROM phenotype WHERE phenotype_id=?',undef,$id);is($value,'16','malformed-reference error leaves the value intact');
 $r=$ua->put("$base/brapi/v1/observations",Content=>encode_json({observations=>[map {{%$payload,observationDbId=>"$id",observationTimeStamp=>"2026-11-02T$_:00:00Z",value=>'18'}} (14,15)]}));
 is($r->code,400,'v1 bulk request cannot repeat one persistent ID with different times');
 ($value)=$schema->storage->dbh->selectrow_array('SELECT value FROM phenotype WHERE phenotype_id=?',undef,$id);is($value,'16','duplicate-ID bulk error makes no partial change');
};
$owned->checkpoint('before_cleanup');
ok($owned->cleanup, 'test-owned committed observation data removed');
done_testing;
