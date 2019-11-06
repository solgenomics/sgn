
use strict;
use Test::More qw | no_plan |;
use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::Stock::SequencingInfo;
use Data::Dumper;

my $f = SGN::Test::Fixture->new();

# create a new SequencingInfo object
#
my $si = CXGN::Stock::SequencingInfo->new( { schema => $f->bcs_schema()  } );

#$si->stock_id(38840);

my $json = "{
    \"stock_id\" : 38840,
    \"organization\" : \"BTI\",
    \"contact_email\" : \"mcclintock\@btiscience.org\",
    \"jbrowse_link\" : \"https://solgenomics.net/jbrowse/myfav\",
    \"website\" : \"https://solgenomics.net\"
}";


$si->from_json($json);

is($si->organization(), "BTI", "organization test");
is($si->contact_email(), 'mcclintock@btiscience.org', "contact email test");
is($si->jbrowse_link(), "https://solgenomics.net/jbrowse/myfav", "jbrowse link test");
is($si->website(), "https://solgenomics.net", "website accessor test");


my $new_json = $si->to_json();

print STDERR Dumper($new_json);
is_deeply(JSON::Any->decode($json), JSON::Any->decode($new_json), "json generation test");

print STDERR "Storing object...\n";
my $stockprop_id = $si->store();
is($si->stockprop_id(), $stockprop_id, "stockprop id test");


print STDERR "Creating new object from database...\n";
my $si2 = CXGN::Stock::SequencingInfo->new( { schema => $f->bcs_schema(), stockprop_id => $stockprop_id });
is($si2->organization(), "BTI", "organization test");
is($si2->contact_email(), 'mcclintock@btiscience.org', "contact email test");
is($si2->jbrowse_link(), "https://solgenomics.net/jbrowse/myfav", "jbrowse link test");
is($si2->website(), "https://solgenomics.net", "website accessor test");
is($si2->stock_id(), $si->stock_id(), "stock_id test");

print STDERR "Deletion test...\n";
ok($si2->delete(), "object delete test");

eval {
    my $si3 = CXGN::Stock::SequencingInfo->new( { schema => $f->bcs_schema(), stockprop_id => $stockprop_id });
};
ok($@, "attempt to create non existing object from database");


done_testing();
