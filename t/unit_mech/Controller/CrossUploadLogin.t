
=head1 NAME

t/unit_mech/Controller/CrossUploadLogin.t - uploading crosses needs a login in every format

=cut

use strict; use warnings;
use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use JSON;

my $f = SGN::Test::Fixture->new();
my $server = 'http://localhost:3010';
my $m = Test::WWW::Mechanize->new(autocheck => 0);

for my $format (qw(spreadsheet barcode)) {
    $m->post("$server/cross/upload_cross",
        Content_Type => 'form-data',
        Content => [ format_type => $format, visible_to_role => 'curator',
                     upload_file => [ undef, "crosses.$format.txt", Content => "x\n" ] ]);
    my $r = eval { decode_json($m->content) } || {};
    like($r->{error} || '', qr/logged in/i, "anonymous $format upload is refused");
}

done_testing();
