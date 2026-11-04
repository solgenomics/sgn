package main;
use strict;
use warnings;
use utf8;
use lib 'lib';
BEGIN {unshift @INC,$ENV{I18N_TEST_PRODUCT_LIB_ROOT} if $ENV{I18N_TEST_PRODUCT_LIB_ROOT};}
use Test::More;
use JSON ();
use Encode qw(encode);
use SGN::I18N;
use Bio::Chado::Schema;
use SGN::Controller::AJAX::Seedlot;
# Whole actual controller and actual JSON decoder/model setters. Only schema
# reads, transaction store and post-store cache dependencies are capture-only.
# No app bootstrap, database connection, ledger write or scientific calculation.
{
    package OwnedListJSONSchema;
    our @ISA=('Bio::Chado::Schema');
    sub resultset {my ($s,$kind)=@_;die 'Unexpected resultset' unless $kind eq 'Stock::Stock';++$s->{resultsets};return bless {schema=>$s},'OwnedListJSONResultSet'}
    sub txn_do {die 'Unexpected transaction callback'}
    package OwnedListJSONResultSet;
    sub find {my ($s,$where)=@_;push @{$s->{schema}{lookups}},$where;die 'Only a canonical unique-name lookup is allowed' unless keys(%$where)==1 && exists($where->{uniquename});return bless {id=>500+@{$s->{schema}{lookups}}},'OwnedListJSONStock'}
    sub create {die 'Unexpected scientific create'}
    sub update {die 'Unexpected scientific update'}
    sub delete {die 'Unexpected scientific delete'}
    package OwnedListJSONStock;
    sub stock_id {shift->{id}}
    package OwnedListJSONRequest;
    sub param {die 'Unexpected request parameter' unless $_[1] eq 'new_transaction_data';return $_[0]{raw}}
    package OwnedListJSONUser;
    sub check_roles {return $_[0]{role} eq $_[1]}
    sub get_object {return shift}
    sub get_username {return 'OwnedOperator_é_Жито_دفعة'}
    sub get_sp_person_id {return 41}
    package OwnedListJSONDetach;
    package OwnedListJSONCache;
    sub set_current_count_property {push @{$OwnedListJSONContext::caches},['count',$_[0]{seedlot_id}]}
    sub set_current_weight_property {push @{$OwnedListJSONContext::caches},['weight',$_[0]{seedlot_id}]}
    package OwnedListJSONContext;
    our ($stores,$caches,$cache_constructors);
    sub new {my ($class,$raw,$role)=@_;$stores=[];$caches=[];$cache_constructors=[];return bless {request=>bless({raw=>$raw},'OwnedListJSONRequest'),user=>$role eq 'anonymous'?undef:bless({role=>$role},'OwnedListJSONUser'),schema=>bless({lookups=>[]},'OwnedListJSONSchema'),stash=>{},translator=>SGN::I18N->new(locale=>'uk',catalog_root=>$ENV{I18N_TEST_CATALOG_ROOT}||'locale/build')},$class}
    sub dbic_schema {++$_[0]{schema_requests};die 'Unexpected schema name' unless $_[1] eq 'Bio::Chado::Schema';return $_[0]{schema}}
    sub req {shift->{request}}
    sub user {shift->{user}}
    sub stash {shift->{stash}}
    sub i18n {shift->{translator}}
    sub detach {die bless {},'OwnedListJSONDetach'}
}
my $json=JSON->new->canonical;
no warnings 'redefine';
local *CXGN::Stock::Seedlot::Transaction::store=sub {
    my $t=shift;my %row=map {$_=>$t->$_()} qw(from_stock to_stock amount weight_gram timestamp description operator factor);
    push @{$OwnedListJSONContext::stores},\%row;return 700+@{$OwnedListJSONContext::stores};
};
local *CXGN::Stock::Seedlot::new=sub {
    my ($class,%args)=@_;push @{$OwnedListJSONContext::cache_constructors},\%args;
    return bless \%args,'OwnedListJSONCache';
};
use warnings 'redefine';
my $rows=[
    {seedlot_name=>'Seed_é_Жито_母_دفعة_<b>A & B</b>_&amp;',number_of_seeds=>'17',transaction_description=>'Списання_é_種子_دفعة_%{count}'},
    {seedlot_name=>'Weight_é_Жито_母_دفعة',weight_g=>'1.25',transaction_description=>'Raw <tag>weight</tag> & reason'},
    {seedlot_name=>'ZeroNumber_Жито',number_of_seeds=>0,weight_g=>0,transaction_description=>'Numeric zero'},
    {seedlot_name=>'ZeroString_Жито',number_of_seeds=>'0',weight_g=>'0',transaction_description=>'String zero'},
    {seedlot_name=>'SignedDecimal_Жито',number_of_seeds=>2,weight_g=>-0.5,transaction_description=>'Transport keeps existing sign/decimal semantics'},
];
my $ascii=[{seedlot_name=>'Seed_ASCII',number_of_seeds=>'17',transaction_description=>'ASCII reason'}];
my @variants=(['Unicode characters',$json->encode($rows),$rows],['Unicode UTF-8 octets',JSON::encode_json($rows),$rows],['ASCII characters',$json->encode($ascii),$ascii],['ASCII octets',JSON::encode_json($ascii),$ascii]);
utf8::upgrade($variants[2][1]);
ok(utf8::is_utf8($variants[0][1]),'Native raw-Unicode request fixture is a decoded character string');
ok(!utf8::is_utf8($variants[1][1]),'Legacy Unicode request fixture contains UTF-8 octets');
for my $role(qw(curator submitter)) {
    for my $v(@variants) {
        my ($label,$raw,$expected)=@$v;my $before=$raw;my $flag=utf8::is_utf8($raw);my $c=OwnedListJSONContext->new($raw,$role);
        my $result=eval {SGN::Controller::AJAX::Seedlot->add_transactions_using_list_POST($c)};my $error=$@;
        is($error,'','Whole native method accepts '.$label.' for '.$role);
        is_deeply($c->stash->{rest},{success=>1},'Original successful response schema is retained');
        is($c->req->param('new_transaction_data'),$before,'Request scientific JSON scalar is not mutated');
        is(utf8::is_utf8($c->req->param('new_transaction_data')),$flag,'Original request scalar UTF-8 flag is not mutated');
        is(scalar(@{$OwnedListJSONContext::stores}),scalar(@$expected),'Exactly one capture-only store per original transaction row');
        is_deeply($c->{schema}{lookups},[map {{uniquename=>$_->{seedlot_name}}} @$expected],'Actual schema lookup receives exact canonical Unicode/literal names');
        for my $index(0..$#$expected) {
            my $in=$expected->[$index];my $t=$OwnedListJSONContext::stores->[$index];
            next unless $t;
            my ($weight,$number)=@$in{qw(weight_g number_of_seeds)};
            if (!defined($weight)) {$weight='NA'} elsif (!defined($number)) {$number='NA'}
            is_deeply($t->{from_stock},[501+$index,$in->{seedlot_name}],'From-stock ID/name pair stays exact');
            is_deeply($t->{to_stock},$t->{from_stock},'Original self-transaction stock pair is retained');
            is($json->encode({amount=>$t->{amount},weight_gram=>$t->{weight_gram}}),$json->encode({amount=>$number,weight_gram=>$weight}),'Actual model setters preserve scalar quantities, zero/string-zero, sign and missing dimension');
            is($t->{description},$in->{transaction_description},'Raw Unicode/literal reason is not a translated message');
            is($t->{operator},'OwnedOperator_é_Жито_دفعة','Original canonical operator is passed unchanged');
            is($t->{factor},-1,'Original consumption factor remains negative one');
            like($t->{timestamp},qr/\A[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}:[0-9]{2}:[0-9]{2}\z/,'Original DateTime timestamp shape remains');
        }
        is_deeply($OwnedListJSONContext::caches,[map {(['count',501+$_],['weight',501+$_])} 0..$#$expected],'Both original cache callbacks follow each completed capture store');
        is_deeply([map {$_->{seedlot_id}} @{$OwnedListJSONContext::cache_constructors}],[map {501+$_} 0..$#$expected],'Cache models receive exact stored seedlot IDs');
    }
}
for my $role(qw(anonymous ordinary)) {
    my $c=OwnedListJSONContext->new('{invalid Unicode Жито',$role);
    eval {SGN::Controller::AJAX::Seedlot->add_transactions_using_list_POST($c)};
    is(ref($@),'OwnedListJSONDetach','Original '.$role.' role exits before decoding, lookup or store');
    my ($context,$source)=$role eq 'anonymous'?('seedlots.server.you_must_be_logged_in_to_add_seedlot_transaction','You must be logged in to add seedlot transactions!'):('seedlots.server.only_a_submitter_or_a_curator_can_add_seedlot_tr.378acfa','Only a submitter or a curator can add seedlot transactions');
    is($c->stash->{rest}{error},$c->i18n->p($context,$source),'Original request-owned role message is retained');
    is_deeply($c->{schema}{lookups},[],'Denied role performs no scientific lookup');
    is_deeply($OwnedListJSONContext::stores,[],'Denied role performs no transaction store');
    is_deeply($OwnedListJSONContext::caches,[],'Denied role performs no cache update');
}
my $invalid_character='{invalid';utf8::upgrade($invalid_character);
for my $raw($invalid_character,encode('UTF-8','{invalid')) {
    my $c=OwnedListJSONContext->new($raw,'curator');eval {SGN::Controller::AJAX::Seedlot->add_transactions_using_list_POST($c)};
    like($@,qr/(?:malformed JSON|expected|unexpected).*character offset/s,'Invalid JSON retains the original native decoder exception');
    ok(!exists($c->stash->{rest}),'Invalid JSON is not converted into successful response data');
    is_deeply($c->{schema}{lookups},[],'Invalid JSON performs no scientific lookup');
    is_deeply($OwnedListJSONContext::stores,[],'Invalid JSON performs no transaction store');
    is_deeply($OwnedListJSONContext::caches,[],'Invalid JSON performs no cache update');
}
my $missing=JSON::encode_json([{seedlot_name=>'BothMissing_ASCII',transaction_description=>'Original unsupported missing dimensions'}]);
my $missing_c=OwnedListJSONContext->new($missing,'curator');eval {SGN::Controller::AJAX::Seedlot->add_transactions_using_list_POST($missing_c)};
like($@,qr/Attribute \(amount\).*type constraint/s,'Original if/elsif leaves both-missing amount undefined and the real model rejects it');
is_deeply($OwnedListJSONContext::stores,[],'Both-missing dimensions do not store a transaction');
is_deeply($OwnedListJSONContext::caches,[],'Both-missing dimensions do not update caches');
done_testing;
