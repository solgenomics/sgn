package SGN::Test;
use File::Spec::Functions;
use File::Temp;
use File::Find;
use FindBin;
use File::Basename;
use File::Temp;
use HTML::Lint;
use List::Util qw/min shuffle/;
use CXGN::VHost::Test;
use Test::More;
our @ISA = qw/Exporter/;
use Exporter;
@EXPORT_OK = qw/validate_urls/;

BEGIN {
    BAIL_OUT "You need to define SGN_TEST_SERVER environment variable"
        unless $ENV{SGN_TEST_SERVER};
}

sub make_dump_tempdir {
    my $d = File::Temp->newdir( catdir( File::Spec->tmpdir, 'validate_error_dump-XXXXXX'), CLEANUP => 0 );
    diag "made dump tempdir '$d'";
    return $d;
}

sub validate_urls {
    my ($urls, $iteration_count) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    $iteration_count ||= 1;

    for my $test_name ( shuffle((sort keys %$urls) x $iteration_count) ) {
        my $url = $urls->{$test_name};
        my $r  = request( $url );
        my $rc = $r->code;

        ok( $rc == 200, "$test_name returned OK" )
            or do {
                diag "fetch actually returned code '$rc': $ENV{SGN_TEST_SERVER}$url";
                if( $ENV{DUMP_ERROR_CONTENT} ) {
                    if ( eval { require Digest::Crc32 } ) {
                        $dump_tempdir ||= make_dump_tempdir();
                        my $script = $r->request->uri->path;
                        $script =~ s/.//;
                        $script =~ s/\W+/_/g;
                        my $params = $r->request->uri->query;
                        $params = $params ? sprintf('%x',Digest::Crc32->new->strcrc32($params)) : '0';
                        my $dump_filename = "${script}_${params}.dump";
                        $dump_filename = catfile( $dump_tempdir, $dump_filename);
                        my $dump_out = IO::File->new( $dump_filename, 'w')
                            or die "$! opening dumpfile $dump_filename for diagnostic dump\n";
                        $dump_out->print("FROM URL: $url\n\n");
                        $dump_out->print($r->content);
                        diag "fetched content dumped to $dump_filename";
                    } else {
                        diag "Cannot include Digest::CRC32 for error content dump.  Skipping.";
                    }
                } else {
                    diag "error dump skipped, set DUMP_ERROR_CONTENT=1 to enable error dump files\n";
                }
            };

        if( $rc == 200 ) { #< successful request
        SKIP: {
                skip 'SKIP_HTML_LINT env set', 2 if $ENV{SKIP_HTML_LINT};
                my $lint = HTML::Lint->new;
                $lint->parse( $r->content );
                my @e = $lint->errors;
                my $e_cnt = @e;

                my $max_errors_to_show = 4;

                is( scalar @e, 0, "$test_name HTML validates" )
                    or diag( "first " . min($e_cnt,$max_errors_to_show) ." of $e_cnt errors:\n",
                            (map {$_->as_string."\n"} @e[0..min($max_errors_to_show,$#e)]),
                            "NOTE: above line numbers refer to the HTML output.\nTo see full error list, run: view_lint.pl '$ENV{SGN_TEST_SERVER}$url'\n"
                        );

                unlike( $r->content, qr/timed out/i, "$test_name does not seem to have timed out" )
                    or diag "fetch from URL $url seems to have timed out";
            }
        } else {
            SKIP: { skip 'because of invalid return code '.$rc, 2 };
        }
    }
    $dump_tempdir and diag "failing output dumped to $dump_tempdir"
}
1;
