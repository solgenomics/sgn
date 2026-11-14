
# CXGN::RespectfulWords with lists given directly (no network): the format of
# the open lists (one word or phrase per line), allowed words, extra words.

use strict;
use warnings;
use utf8;
use Test::More;
use CXGN::RespectfulWords;

my %lists = (
    en => "shit\nboob\nfuck\nsuck\n",
    pt => "merda\nfilho da puta\ncaralho\nsaco\npinto\ndesgraça\nvai tomar no cu\n",
    es => "Mierda\nHijo de puta\nmartillo\n",
);
my $ck = CXGN::RespectfulWords->new(lists => \%lists);

foreach my $ok ('Very good taste, high yield', 'Boa produtividade e ótimo sabor', 'class assessment in Scunthorpe',
                'saco de 50 kg', 'Maria Pinto', 'martillo', 'Bob', 'insects suck the sap', '', undef, 'cuidado com a cultura') {
    is_deeply([ $ck->find($ok) ], [], 'respectful: ' . ($ok // 'undef'));
}

is_deeply([ $ck->find('que MERDA de variedade') ], [ 'merda' ], 'upper case');
is_deeply([ $ck->find('merdaaaa') ], [ 'merda' ], 'repeated letters');
is_deeply([ $ck->find('é uma desgraca') ], [ 'desgraça' ], 'accents ignored (reported as listed)');
is_deeply([ $ck->find('esto es una mierda!') ], [ 'mierda' ], 'Spanish, punctuation');
is_deeply([ $ck->find('seu filho-da-puta') ], [ 'filho da puta' ], 'phrases');
is_deeply([ $ck->find('this is shit, a merda') ], [ 'shit', 'merda' ], 'several words');
is_deeply([ $ck->find('damn bullshit') ], [ 'bullshit' ], 'English of Regexp::Common::profanity');

my $site = CXGN::RespectfulWords->new(lists => \%lists, allowed => [ 'merda' ], blocked => [ 'horrible', 'mau cheiro' ]);
is_deeply([ $site->find('merda') ], [], 'allowed by the site');
is_deeply([ $site->find('a horrible variety') ], [ 'horrible' ], 'word added by the site');
is_deeply([ $site->find('tem mau cheiro') ], [ 'mau cheiro' ], 'phrase added by the site');

my $none = CXGN::RespectfulWords->new(lists => \%lists, allowed_default => 0);
is_deeply([ $none->find('saco') ], [ 'saco' ], 'without the default allowed words');

my $offline = CXGN::RespectfulWords->new(lists => {});
is_deeply([ $offline->find('fuck') ], [ 'fuck' ], 'without lists, English still checked');

done_testing();
