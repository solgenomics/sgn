=head1 NAME

t/unit/SGN/Controller/JavaScript.t - script list built for the page wrapper

=head1 DESCRIPTION

Pages and the components they include can each request the same JavaScript
entry module through /util/import_javascript.mas. The page must still get
each script tag only once, or the second copy of the webpack entry script sets
window.jsMod.<entry> to undefined.

=cut

use strict;
use warnings;

use Test::More;
use File::Temp qw | tempdir |;
use JSON;

# The controller reads its default config from SGN->path_to() when it is
# loaded. Provide that here, so the test does not need to start the whole
# application.
BEGIN {
    package SGN;
    sub path_to { shift; return join('/', '.', @_); }
}

use SGN::Controller::JavaScript;

{
    package Test::Context;
    sub new { my ($class, %stash) = @_; return bless { stash => \%stash }, $class; }
    sub stash { return $_[0]->{stash}; }
}

my $dir = tempdir(CLEANUP => 1);
my $mapping = "$dir/mapping.json";
open(my $fh, '>', $mapping) or die "Can't write $mapping: $!";
print $fh encode_json({
    sequenced_accessions => { files => [ 'runtime.min.js', 'sequenced_accessions.min.js' ], legacy => [] },
    fieldmap => { files => [ 'runtime.min.js', 'chunk.1234.js', 'fieldmap.min.js' ], legacy => [] },
});
close($fh);

my $controller = SGN::Controller::JavaScript->new({
    js_path => $dir,
    js_legacy_path => $dir,
    dependency_json_path => $mapping,
});

# stock/index.mas, page/detail_page_2_col_section.mas and
# stock/sequencing_status.mas all request "sequenced_accessions" for one
# accession page.
my $c = Test::Context->new(
    jsan_classes => [],
    js_modules => [ 'sequenced_accessions', 'sequenced_accessions', 'fieldmap', 'sequenced_accessions' ],
);
$controller->resolve_javascript_classes($c);

is_deeply(
    $c->stash->{js_uris},
    [
        '/js/build/runtime.min.js',
        '/js/build/sequenced_accessions.min.js',
        '/js/build/chunk.1234.js',
        '/js/build/fieldmap.min.js',
    ],
    'each script is listed once, in the order it is first needed',
);

done_testing();
