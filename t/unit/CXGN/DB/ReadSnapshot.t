use strict;use warnings;use Test::More;use CXGN::DB::ReadSnapshot;
{package SnapshotFakeHandle;sub state {$_[0]{state}} sub do {$_[0]{sql}=$_[1];$_[0]{isolation}='repeatable read';1}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
{package SnapshotFakeSchema;
 sub storage {$_[0]}sub dbh {$_[0]{handle}}
 sub txn_begin {$_[0]{begin}++;$_[0]{handle}{AutoCommit}=0}
 sub txn_commit {$_[0]{commit}++;$_[0]{handle}{AutoCommit}=1}
 sub txn_rollback {$_[0]{rollback}++;$_[0]{handle}{AutoCommit}=1;$_[0]{handle}{state}=''}
}
sub schema {bless({handle=>bless({AutoCommit=>1,state=>'',isolation=>'read committed'},'SnapshotFakeHandle'),begin=>0,commit=>0,rollback=>0},'SnapshotFakeSchema')}
my$s=schema();
my@values=CXGN::DB::ReadSnapshot::run($s,sub {ok(wantarray,'callback receives list context');return('first','last')});
is_deeply(\@values,['first','last'],'all list values are returned');
my$value=CXGN::DB::ReadSnapshot::run($s,sub {ok(defined(wantarray)&&!wantarray,'callback receives scalar context');return('first','last')});
is($value,'last','scalar return semantics are unchanged');
my$void;CXGN::DB::ReadSnapshot::run($s,sub {$void=!defined(wantarray)});ok($void,'void context reaches the callback');
is(CXGN::DB::ReadSnapshot::run($s,sub {0}),0,'false scalar results remain successful');
is(CXGN::DB::ReadSnapshot::run($s,sub {undef}),undef,'undefined scalar result is preserved');
is($s->{commit},5,'each successful owned transaction commits');ok($s->dbh->{AutoCommit},'owned connection returns to AutoCommit');
like($s->dbh->{sql},qr/REPEATABLE READ/,'owned read selects a consistent snapshot');unlike($s->dbh->{sql},qr/READ ONLY/,'layout-cache writes are not forbidden');
$s=schema();$s->dbh->{AutoCommit}=0;$s->dbh->{isolation}='serializable';
@values=CXGN::DB::ReadSnapshot::run($s,sub {ok(wantarray,'caller-owned callback also keeps list context');return('caller','value')});
is_deeply(\@values,['caller','value'],'caller-owned return values are retained');is_deeply([@{$s}{qw(begin commit rollback)}],[0,0,0],'caller-owned transaction is never begun, committed or rolled back');
is(CXGN::DB::ReadSnapshot::run($s,sub {die 'Wrong caller-owned scalar context' if wantarray;return 0}),0,'caller-owned scalar zero is preserved');
my $caller_void;CXGN::DB::ReadSnapshot::run($s,sub {$caller_void=!defined(wantarray)});ok($caller_void,'caller-owned void context is preserved');
is($s->dbh->{isolation},'serializable','caller isolation policy is untouched');ok(!$s->dbh->{AutoCommit},'caller remains in its transaction');
my$attempts=0;my$ok=eval {CXGN::DB::ReadSnapshot::run($s,sub {++$attempts;die "caller failure\n"});1};ok(!$ok,'caller error remains explicit');is($attempts,1,'caller-owned error is never retried');is($s->{rollback},0,'caller-owned error does not roll back caller work');
$s=schema();$attempts=0;
is(CXGN::DB::ReadSnapshot::run($s,sub {if(++$attempts==1){$s->dbh->{state}='40001';die "serialization first\n"}return'retried'}),'retried','serialization failure retries successfully');
is($attempts,2,'one and only one retry is attempted');is($s->{rollback},1,'failed owned attempt is rolled back before retry');is($s->{commit},1,'only the successful attempt commits');
$s=schema();$attempts=0;$ok=eval {CXGN::DB::ReadSnapshot::run($s,sub {++$attempts;$s->dbh->{state}='40001';die "persistent serialization\n"});1};ok(!$ok,'persistent serialization failure stays explicit');is($attempts,2,'persistent conflict is bounded to two attempts');like($@,qr/persistent serialization/,'original serialization error is retained');is($s->{rollback},2,'both failed owned attempts are rolled back');
$s=schema();$attempts=0;$ok=eval {CXGN::DB::ReadSnapshot::run($s,sub {++$attempts;$s->dbh->{state}='22012';die "nonserialization error\n"});1};ok(!$ok,'other SQL errors remain explicit');is($attempts,1,'other SQLSTATE is not retried');is($s->{rollback},1,'other owned error is rolled back once');like($@,qr/nonserialization error/,'other error text is preserved');
done_testing;
