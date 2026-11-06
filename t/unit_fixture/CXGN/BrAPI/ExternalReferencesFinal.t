use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use CXGN::BrAPI::v2::ExternalReferences;

sub validate {CXGN::BrAPI::v2::ExternalReferences::validate_payload($_[0])}
ok(!validate([{referenceSource=>'source',referenceId=>'0',optional=>undef}]),'string zero and optional null/scalar fields are valid');
ok(!validate([{referenceSource=>'0',referenceID=>'0'}]),'legacy alias and source zero are valid');
for my $bad ({referenceSource=>'source',referenceId=>'id'},[undef],[{referenceSource=>'source',referenceId=>{nested=>'bad'}}],[{referenceSource=>'',referenceId=>'id'}],[{referenceSource=>'source',referenceId=>'a',referenceID=>'b'}]) {
    is(validate($bad)->{code},400,'malformed reference payload refused before storage');
}

my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;$s->storage->auto_savepoint(1);
my $id=$s->resultset('Stock::Stock')->find({uniquename=>'test_trial210'})->stock_id;
my $prefix='external_refs_final_';
sub refs {CXGN::BrAPI::v2::ExternalReferences->new({bcs_schema=>$s,table_name=>'stock',table_id_key=>'stock_id',id=>"$id",external_references=>$_[0]})}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s;}
$s->txn_begin;$tx=1;
my $ran=eval {
    my $zero=refs([{referenceSource=>$prefix.'source',referenceId=>'0'}]);
    ok($zero->store->{success},'zero reference ID stored');
    is_deeply($zero->search->{$id},[{referenceSource=>$prefix.'source',referenceId=>'0'}],'zero ID returned exactly');
    my $alias=refs([{referenceSource=>'0',referenceID=>'0',optional=>undef}]);
    ok($alias->store->{success},'source zero and legacy alias stored');
    is_deeply($alias->search->{$id},[{referenceSource=>'0',referenceId=>'0'}],'both source and ID zero preserved on read');
    my $bad=refs([{referenceSource=>$prefix.'source',referenceId=>{nested=>'bad'}}]);
    is($bad->store->{code},400,'bad payload produces controlled storage error');
    is_deeply($alias->search->{$id},[{referenceSource=>'0',referenceId=>'0'}],'invalid replacement never deletes previous references');
    my $absent=CXGN::BrAPI::v2::ExternalReferences->new({bcs_schema=>$s,table_name=>'stock',table_id_key=>'stock_id',id=>"$id"});
    ok($absent->store->{success},'absent optional payload is a no-op');
    is_deeply($alias->search->{$id},[{referenceSource=>'0',referenceId=>'0'}],'absent optional data preserves references');
    my $empty=CXGN::BrAPI::v2::ExternalReferences->new({bcs_schema=>$s,table_name=>'stock',table_id_key=>'stock_id',id=>[]});
    is_deeply($empty->search,{},'explicit empty target list does not fetch every stock reference');
    ok(refs([])->store->{success},'explicit empty reference array clears the target');
    is_deeply($alias->search,{},'clear operation removed the target references');
    1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'reference roundtrip cases completed and rolled back') or diag($error);
done_testing;
