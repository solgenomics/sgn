use strict;
use warnings;
use Test::More;
use CXGN::BreederSearch;

# No DB or process is mocked below the policy under test: only the existing
# external refresh boundary is instrumented so these tests cannot spawn workers.
my $bs=CXGN::BreederSearch->new({dbh=>'unused by instrumented refresh boundary'});
my @args=('fixture-host','fixture-db','fixture-user','fixture-not-a-secret','phenotypes','concurrent','/fixture/sgn');
subtest 'An older busy refresh is waited for, then a synchronous new refresh runs'=>sub {
 my @calls;
 no warnings 'redefine';
 local *CXGN::BreederSearch::refresh_matviews=sub {push @calls,[@_];return @calls==1?{busy=>1,error=>'already in progress'}:{message=>'completed'}};
 my $r=$bs->refresh_matviews_after_change(@args,1);
 ok($r->{success},'refresh completed after busy state cleared');is(scalar @calls,2,'only explicit busy state was retried');
 is($calls[0][-1],0,'first attempt used synchronous execution');is($calls[1][-1],0,'retry cannot detach another background worker');
};
subtest 'Busy timeout is explicit pending work, never a false success'=>sub {
 my $calls=0;no warnings 'redefine';
 local *CXGN::BreederSearch::refresh_matviews=sub {$calls++;return {busy=>1,error=>'already in progress'}};
 my $r=$bs->refresh_matviews_after_change(@args,0);
 ok($r->{refresh_pending},'timeout leaves explicit pending state');ok(!$r->{success},'timeout does not claim a refresh happened');is($calls,1,'zero wait budget spawns no retries');
};
subtest 'Non-busy failures are not retried or silently dropped'=>sub {
 my $calls=0;no warnings 'redefine';
 local *CXGN::BreederSearch::refresh_matviews=sub {$calls++;return {error=>'could not start refresh'}};
 my $r=$bs->refresh_matviews_after_change(@args,1);
 ok($r->{refresh_pending},'failed refresh remains explicit');is($r->{error},'could not start refresh','failure reason is retained');is($calls,1,'non-busy errors do not retry a possibly started operation');
};
subtest 'A runner exception becomes pending refresh without an orphan retry'=>sub {
 my $calls=0;no warnings 'redefine';
 local *CXGN::BreederSearch::refresh_matviews=sub {$calls++;die 'runner failed'};
 my $r=$bs->refresh_matviews_after_change(@args,1);
 ok($r->{refresh_pending},'exception has an explicit pending result');is($calls,1,'exception is not retried');
};
done_testing;
