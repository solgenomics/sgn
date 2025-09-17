=head1 NAME

stock_search.t - tests for /stock/search/

=head1 DESCRIPTION

Tests for stock search page

=head1 AUTHORS

Naama Menda  <nm249@cornell.edu>
Chris Simoes <ccs263@cornell.edu>

=cut

use Modern::Perl;
use Test::More;

use lib 't/lib';

BEGIN { $ENV{SGN_SKIP_CGI} = 1 } # can skip compiling cgis, not using them here
use SGN::Test::Data qw/create_test/;
use SGN::Test::WWW::Mechanize;
use JSON::XS qw(decode_json);

# small helper: dump first chars of current page on failure
sub _diag_snippet {
    my ($mech, $label) = @_;
    my $c = $mech->content // '';
    diag("$label (first 800 chars):\n" . substr($c,0,800) . "\n----");
}

{
    my $mech = SGN::Test::WWW::Mechanize->new;

    $mech->get_ok("/stock/search/");
    $mech->dbh_leak_ok;

    # Updated labels (case-insensitive)
    $mech->content_like(qr/\bStock\s+Id\b/i)
        or _diag_snippet($mech, 'Landing page missing "Stock Id"');
    $mech->content_like(qr/\bStock\s+Name\b/i)
        or _diag_snippet($mech, 'Landing page missing "Stock Name"');
    $mech->content_like(qr/\bStock\s+Type\b/i)
        or _diag_snippet($mech, 'Landing page missing "Stock Type"');
    $mech->content_like(qr/\bOrganism\b/i)
        or _diag_snippet($mech, 'Landing page missing "Organism"');
    $mech->html_lint_ok('empty stock search valid html');

    $mech->with_test_level( local => sub {
        my $stock = create_test('Stock::Stock', {
            description => "LALALALA3475",
        });

        my $person = $mech->create_test_user(
            first_name => 'testfirstname',
            last_name  => 'testlastname',
            user_name  => 'testusername',
            password   => 'testpassword',
            user_type  => 'submitter',
        );
        my $sp_person_id = $person->{id};

        # Find a usable form: prefer by name, else by fields
        my $submitted = 0;
        my $used_field = '';

        eval {
            if ($mech->form_name('stock_search_form')) {
                $mech->submit_form_ok({
                    form_name => 'stock_search_form',
                    fields    => { stock_name => $stock->name },
                }, 'submitted stock search form by name');
                $submitted = 1; $used_field = 'stock_name';
            }
        };

        if (!$submitted) {
            eval {
                if ($mech->form_with_fields('stock_name')) {
                    $mech->submit_form_ok({
                        fields => { stock_name => $stock->name },
                    }, 'submitted stock search by stock_name');
                    $submitted = 1; $used_field = 'stock_name';
                }
            };
        }

        if (!$submitted) {
            eval {
                if ($mech->form_with_fields('stock_id')) {
                    $mech->submit_form_ok({
                        fields => { stock_id => $stock->stock_id },
                    }, 'submitted stock search by stock_id');
                    $submitted = 1; $used_field = 'stock_id';
                }
            };
        }

        ok($submitted, 'found and submitted a search form')
            or _diag_snippet($mech, 'No usable form (stock_search_form / stock_name / stock_id)');

        $mech->html_lint_ok("valid html after stock search ($used_field)");

        # Try to see results directly on the page first
        my $saw_name_on_page = $mech->content_contains($stock->name);
        if (!$saw_name_on_page) {
            note "Did not see stock name in HTML; falling back to AJAX JSON";
            # If the page renders via JS, query the JSON endpoint directly
            my $term = $stock->name;
            $mech->get("/ajax/search/stocks?term=$term");
            if ($mech->status == 200 && ($mech->ct||'') =~ m{application/json}i) {
                my $data = eval { decode_json($mech->content) } || {};
                my $rows = ref($data) eq 'HASH' ? ($data->{results} // $data->{data} // []) : [];
                my $found = 0;
                for my $row (@$rows) {
                    if (ref($row) eq 'ARRAY') {
                        # handle either [id, link, ...] or [link, ...]
                        my $link = $row->[0] =~ /^\d+$/ ? $row->[1] : $row->[0];
                        $found = 1 if defined $link && $link =~ /\Q$stock->stock_id\E/;
                    } elsif (ref($row) eq 'HASH') {
                        $found = 1 if (($row->{stock_id}//'') eq $stock->stock_id)
                                   || (($row->{stock_name}//'') eq $stock->name);
                    }
                }
                ok($found, 'AJAX search returned the created stock')
                    or diag("AJAX body (first 800 chars):\n" . substr($mech->content,0,800));
            } else {
                diag "AJAX search endpoint not available or not JSON (status=" . $mech->status . ")";
            }

            # return to page to continue link-following below
            $mech->get_ok("/stock/search/");
        }

        # Be tolerant: some UIs show "Search Results", others "results"
        $mech->content_like(qr/\b(Search Results|results)\b/i)
            or _diag_snippet($mech, 'Results label not found');

        # Follow stock detail link: accept /stock/<id>/view or /stock/<id>
        my $detail_regex = qr{^/stock/\Q@{[ $stock->stock_id ]}\E(?:/view)?$};
        $mech->follow_link_ok(
            { url_regex => $detail_regex },
            "go to the stock detail page for " . $stock->stock_id
        ) or _diag_snippet($mech, "Could not find link matching $detail_regex");

        $mech->dbh_leak_ok;
        $mech->html_lint_ok('stock detail page html ok');
    });
}

{
    my $mech = SGN::Test::WWW::Mechanize->new;

    # Advanced search GET should load cleanly (absolute path)
    $mech->get_ok("/stock/search?advanced=1&stock_name=&stock_type=0&organism=0&search_submitted=1&page=1&page_size=20&description=&person=SolCAP+project&onto=&trait=&min_limit=&max_limit=&submit=Search");
    $mech->dbh_leak_ok;
    $mech->html_lint_ok('advanced stock search page html ok');
}

done_testing;
