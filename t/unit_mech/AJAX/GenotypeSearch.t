use strict;
use warnings;

use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Test::WWW::Mechanize;

use Data::Dumper;
use JSON;
use CXGN::List;

my $f = SGN::Test::Fixture->new();
my $sp_person_id = 40;

my $mech = SGN::Test::WWW::Mechanize->new();

# Create a list of Accessions to search on
my @accession_names = ("UG120036", "UG120037", "UG120038", "UG120130", "test_accession2", "test_accession5");
my $list_id = CXGN::List::create_list($f->dbh(), "Genotype Filter Accessions", "A list of accessions to use when filtering genotype data.", $sp_person_id);
my $list = CXGN::List->new({ dbh => $f->dbh(), list_id => $list_id });
$list->type('accessions');
is($list->name(), "Genotype Filter Accessions", "check list name");
is($list->type(), "accessions", "check list type");

# Add accession names to list
foreach (@accession_names) {
    my $err = $list->add_element($_);
    ok(!$err, "adding an element to the list");
}
my $elements = $list->elements();
is_deeply($elements, \@accession_names, "check list elements");


# Test Genotype Protocol Filter
my $expected_response = {
    'error' => undef,
    'results' => {
        'matches' => {
            'accessions_by_genotyping_protocol' => {
                '1' => [ 38913, 38915, 39964, 38914 ]
            },
            'genotyping_protocols_by_accession' => {
                '38915' => [ 1 ],
                '38913' => [ 1 ],
                '38914' => [ 1 ],
                '39964' => [ 1 ]
            }
        },
        'lookups' => {
            'genotyping_protocols' => {
                '1' => 'GBS ApeKI genotyping v4'
            },
            'accessions' => {
                '38913' => 'UG120036',
                '38915' => 'UG120038',
                '38844' => 'test_accession5',
                '38914' => 'UG120037',
                '38841' => 'test_accession2',
                '39964' => 'UG120130'
            }
        },
        'counts' => {
            'accessions_by_genotyping_protocol' => {
                '1' => 4
            },
            'ranked_genotyping_protocols' => [ '1' ],
            'genotyping_protocols_by_accession' => {
                '38914' => 1,
                '38915' => 1,
                '38913' => 1,
                '39964' => 1
            },
            'accessions_total' => 6
        }
    }
};
$mech->post_ok("http://localhost:3010/ajax/genotyping_protocol/search/accession_list", { accession_list_id => $list_id });
my $response = decode_json $mech->content();
is_deeply($response, $expected_response, "Check genotyping protocol filter response");

print STDERR "\n\n\n\n\====> PROTO RESP:\n";
print STDERR Dumper $response;


# Test Genotype Project Filer
$expected_response = {
    'results' => {
        'matches' => {
            'accessions_by_genotyping_project' => {
                '140' => [ 38913, 38915, 38914 ],
                '142' => [ 38913, 38915, 39964, 38914 ]
            },
            'genotyping_projects_by_accession' => {
                '38913' => [ 142, 140 ],
                '38914' => [ 140, 142 ],
                '38915' => [ 140, 142 ],
                '39964' => [ 142 ],
            }
        },
        'lookups' => {
            'accessions' => {
                '38841' => 'test_accession2',
                '38914' => 'UG120037',
                '38915' => 'UG120038',
                '38844' => 'test_accession5',
                '38913' => 'UG120036',
                '39964' => 'UG120130',
            },
            'genotyping_projects' => {
                '140' => 'test_genotyping_project',
                '142' => 'test_population2'
            }
        },
        'counts' => {
            'accessions_total' => 6,
            'genotyping_projects_by_accession' => {
                '39964' => 1,
                '38913' => 2,
                '38915' => 2,
                '38914' => 2
            },
            'accessions_by_genotyping_project' => {
                '140' => 3,
                '142' => 4
            },
            'ranked_genotyping_projects' => [
                '142',
                '140'
            ]
        }
    },
    'error' => undef
};
$mech->post_ok("http://localhost:3010/ajax/genotyping_project/search/accession_list", { accession_list_id => $list_id });
$response = decode_json $mech->content();
is_deeply($response, $expected_response, "Check genotyping project filter response");

print STDERR "\n\n\n\n\n===> PROJ RESPONSE:\n";
print STDERR Dumper $response;

# Remove the list when done
CXGN::List::delete_list($f->dbh(), $list_id);

done_testing();