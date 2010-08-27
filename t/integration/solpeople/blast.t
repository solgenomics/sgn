use strict;
use warnings;

use Test::More tests => 11;
use Test::WWW::Mechanize;
use lib 't/lib';
use SGN::Test;
use SGN::Test::WWW::Mechanize;
my $mech = SGN::Test::WWW::Mechanize->new;

$mech->while_logged_in( user_type => 'user', sub {
    $mech->get_ok('/tools/blast/watch/index.pl');
    $mech->content_contains('SGN BLAST Watch');
    $mech->submit_form_ok({
            form_number => 2,
            fields    => {
                submit  => 'Submit',
                program => 'blastn',
                database => "unigene/all_current",
                matrix => "BLOSUM62",
                evalue   => "1.0",
                sequence => "ATCG",
            },
        },
    );
    $mech->content_contains('Your query has been added to SGN BLAST Watch.');
    $mech->content_contains('You will receive an email when there are new results.');

});
