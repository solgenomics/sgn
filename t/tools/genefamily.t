

use strict;
use lib 't/lib';

use Test::More tests=>13;
use SGN::Test::WWW::Mechanize;

my $m = SGN::Test::WWW::Mechanize->new();

$m->while_logged_in( { user_type => 'curator' }, sub {

    $m->get_ok('/tools/genefamily/search.pl');

    my $form1 = {
        form_name => 'genefamily_detail_form',
        fields => { 'genefamily_id' => 0,
                    'dataset' => 'test',
                }
       };

    $m->submit_form_ok($form1, "submit genefamily form");


    $m->back();

    my $form2 = {
        form_name => 'member_search_form',
        fields => {
            member_id => 'At1g13780',
            dataset => 'test',
        }
       };

    $m->submit_form_ok($form2, "submit member form");

    $m->content_like(qr/At1g13780/, "found required sequence");
    #print $m->content;

    my $f3 = {
        form_name => 'genefamily_display_form',
    };

    $m->submit_form_ok($f3, "click view family button");

    my $f4 = {
        form_name => 'alignment_viewer_form',
    };
    $m->submit_form_ok($f4, "click alignment button");
    $m->content_like(qr/At1g13780/i, "id on align viewer page");

});

