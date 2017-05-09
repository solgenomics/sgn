
use strict;

use lib 't/lib';

use Test::More;
use Data::Dumper;
use SGN::Test::Fixture;
use CXGN::Onto;

my $t = SGN::Test::Fixture->new();
my $onto = CXGN::Onto->new( { schema => $t->bcs_schema() });

my $cv_type = 'attribute_ontology';
my @results = $onto->get_root_nodes($cv_type);
#print STDERR "test 1 results " .Dumper @results;

is_deeply(@results, [
               59,
               'CHEBI:00000 chebi_compounds'
             ], 'onto get root nodes test');

=for comment
my $cv_id = 58; # CASSTISS ontology with cvprop 'object'
@results = $onto->get_terms($cv_id);
print STDERR "test 2 results: @results";
my @cass_tissues = ["[77181,'cass fibrous root|CASSTISS:0000011']",
                    "[77176,'cass lower leaf|CASSTISS:0000006']",
                    "[77171,'cass lower stem bark|CASSTISS:0000010']",
                    "[77174,'cass lower stem whole|CASSTISS:0000009']",
                    "[77178,'cass pre-storage root|CASSTISS:0000012']",
                    "[77180,'cass sink leaf|CASSTISS:0000004']",
                    "[77170,'cass source leaf|CASSTISS:0000005']",
                    "[77168,'cass storage root|CASSTISS:0000013']",
                    "[77172,'cass upper stem|CASSTISS:0000007']"];
                    # problem with this data structure
is_deeply(@results, @cass_tissues, 'onto get terms test');
=cut

my $ids = "77172,77285,77412,77470";
@results = $onto->compose_trait($ids);
print STDERR Dumper "test 3 results ".@results;

is_deeply(@results, {
               'cvterm_id' => 77560,
               'name' => 'cass upper stem|zinc atom|ug/g|week 54|COMP:0000014'
             }, 'onto compose trait test');

done_testing();
