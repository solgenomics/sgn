
# Answers of the ANA service in Portuguese never reach the page: "no data"
# (Sem dados ...) is an empty result, other errors give a standard English
# message. get_raw is replaced by a canned answer: no network.

use strict;
use warnings;
use utf8;

use Test::More;
use File::Temp qw(tempdir);
use Encode qw(encode);
use CXGN::Weather;

my $answer;
{
    no warnings 'redefine';
    *CXGN::Weather::get_raw = sub { return $answer };
}
my $wx = CXGN::Weather->new({ cache_dir => tempdir(CLEANUP => 1) });
my $daily = sub { return eval { $wx->station_daily('ana', '60381000', -19.2, -44.0, 700, '2026-11-01', '2026-11-02') } };

# no data for these dates (bytes as they come from the service, UTF-8)
$answer = encode('UTF-8', '<DataSet><Error>Sem dados para esta estação (Código: 60381000) no período solicitado!</Error></DataSet>');
my $r = $daily->();
is($@, '', 'no data is not an error');
is_deeply($r->{days}, [], 'no days: the page says the station sent no observations');
is($r->{rain_only}, 1, 'still an ANA rain gauge');

# any other error: standard English message, not the Portuguese text
$answer = encode('UTF-8', '<DataSet><Error>Falha de conexão com o banco de dados</Error></DataSet>');
{
    my @warned;
    local $SIG{__WARN__} = sub { push @warned, @_ };
    $r = $daily->();
    like($@, qr/^The ANA service could not give the data of station 60381000 for these dates/, 'standard message');
    unlike($@, qr/conex|Falha/, 'no Portuguese on the page');
    like(join('', @warned), qr/ANA error for station 60381000/, 'original message in the log');
}

done_testing();
