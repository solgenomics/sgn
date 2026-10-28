use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP;
use Digest::SHA qw(sha256_hex);
use Scalar::Util qw(weaken refaddr);
use SGN::I18N;

# Tiny owned fixtures, not a corpus/RSS benchmark. Observe object lifetimes
# without adding a public cache-statistics interface to the application.
my $json = JSON::PP->new->canonical->utf8;
my $root = tempdir(CLEANUP => 1);
sub catalog {
    my ($locale, $label, $parent) = @_;
    return {
        schema => 1, api => 1, locale => $locale, direction => 'ltr',
        sourceRevision => sha256_hex($label), nplurals => 2,
        pluralForms => 'nplurals=2; plural=(n != 1);',
        pluralAst => {type => 'NEQ', left => {type => 'VAR'}, right => {type => 'NUM', val => 1}},
        messages => {
            "cache.label\x04Label" => {plural => undef, forms => [$label]},
            ($parent ? ("cache.parent\x04Parent label" => {plural => undef, forms => [$parent]}) : ()),
            "cache.count\x04%{count} item" => {plural => '%{count} items', forms => ['%{count} item', '%{count} items']},
        },
    };
}
sub write_catalog {
    my ($branch, $locale, $domain, $data) = @_;
    make_path("$root/$branch/$locale");
    open my $file, '>:raw', "$root/$branch/$locale/$domain.json" or die $!;
    print {$file} $json->encode($data); close $file;
}
sub translator {
    my ($branch, $locale, $domain) = @_;
    return SGN::I18N->new(catalog_root => "$root/$branch", locale => $locale // 'zz', domain => $domain // 'sgn');
}
sub churn {
    my ($branch, $prefix, $count) = @_;
    for my $version (1 .. $count) {
        write_catalog($branch, 'zz', 'sgn', catalog('zz', "$prefix-$version"));
        my $request = translator($branch);
        is($request->p('cache.label', 'Label'), "$prefix-$version", 'current tiny version is admitted');
    }
}

my $initial = catalog('zz', 'initial');
write_catalog('primary', 'zz', 'sgn', $initial);
my $old = translator('primary');
my $old_export = $old->export_catalog;
my $weak_old = $old->{catalogs}[0]; weaken($weak_old);
{
    my $same = translator('primary');
    is(refaddr($same->{catalogs}[0]), refaddr($old->{catalogs}[0]), 'retained same content is reused');
}
churn('primary', 'replacement', 8);
is($old->p('cache.label', 'Label'), 'initial', 'old active request keeps its immutable version after cache eviction');
ok(defined $weak_old, 'old catalog remains alive while its request owns it');
undef $old;
ok(!defined $weak_old, 'evicted old catalog is collectable after the request completes');

my $current = translator('primary');
write_catalog('second', 'zz', 'reports', catalog('zz', 'replacement-8'));
my $other_domain = translator('second', 'zz', 'reports');
is($other_domain->p('cache.label', 'Label'), 'replacement-8', 'another root/domain retains correct content');
is(refaddr($other_domain->{catalogs}[0]), refaddr($current->{catalogs}[0]), 'identical validated locale/content can share across roots/domains');
is($other_domain->export_catalog->{domain}, 'reports', 'translator domain remains request-owned');
write_catalog('third', 'zz', 'reports', catalog('zz', 'other-root'));
my $different = translator('third', 'zz', 'reports');
is($different->p('cache.label', 'Label'), 'other-root', 'different root content is not confused');
is($current->p('cache.label', 'Label'), 'replacement-8', 'another root does not mutate the first snapshot');

# Failed validation neither admits nor touches a cache entry. A retained live
# object still has a cache hit after more than eight distinct invalid files.
for my $version (1 .. 12) {
    my $bad = catalog('zz', "bad-$version");
    $bad->{pluralAst} = {type => 'EVAL'};
    write_catalog('invalid', 'zz', 'sgn', $bad);
    my $ok = eval { translator('invalid'); 1 };
    ok(!$ok && $@ =~ /Unsupported plural AST/, 'malformed present catalog still fails explicitly');
}
my $repeat_invalid = eval { translator('invalid'); 1 };
ok(!$repeat_invalid && $@ =~ /Unsupported plural AST/, 'repeated malformed bytes cannot become a cached English fallback');
my $after_failed = translator('primary');
is(refaddr($after_failed->{catalogs}[0]), refaddr($current->{catalogs}[0]), 'failed catalog churn cannot evict valid retained content');
write_catalog('wrong-locale', 'ab', 'sgn', catalog('zz', 'replacement-8'));
my $wrong_ok = eval { translator('wrong-locale', 'ab'); 1 };
ok(!$wrong_ok && $@ =~ /locale mismatch/, 'cache key still validates expected locale across identical bytes');
is(translator('missing', 'zz-AA')->locale, 'en', 'missing catalog keeps whole English fallback');
is(translator('missing', 'zz-AA')->np('cache.count', '%{count} item', '%{count} items', 0, {count => 0}), '0 items', 'missing catalog keeps English plural behavior');

write_catalog('primary', 'zz', 'sgn', $initial);
my $rollback = translator('primary');
is_deeply($rollback->export_catalog, $old_export, 'rollback reloads exact original catalog/presentation parity');
is($rollback->np('cache.count', '%{count} item', '%{count} items', 2, {count => 2}), '2 items', 'plural semantics survive rollback');

write_catalog('regional', 'zz', 'sgn', catalog('zz', 'parent-old', 'parent-only-old'));
my $child = catalog('zz-AA', 'child-old');
delete $child->{messages}{"cache.count\x04%{count} item"};
write_catalog('regional', 'zz-AA', 'sgn', $child);
my $chain = translator('regional', 'zz-AA');
my $weak_child = $chain->{catalogs}[0]; weaken($weak_child);
my $weak_parent = $chain->{catalogs}[1]; weaken($weak_parent);
is($chain->requested_locale, 'zz-AA', 'regional requested locale remains unchanged');
is($chain->locale, 'zz-AA', 'regional catalog remains first');
is($chain->p('cache.label', 'Label'), 'child-old', 'regional message overrides its parent');
is($chain->p('cache.parent', 'Parent label'), 'parent-only-old', 'parent missing-message fallback remains available');
churn('unrelated', 'unrelated', 8);
write_catalog('regional', 'zz', 'sgn', catalog('zz', 'parent-new', 'parent-only-new'));
write_catalog('regional', 'zz-AA', 'sgn', catalog('zz-AA', 'child-new'));
my $new_chain = translator('regional', 'zz-AA');
is($new_chain->p('cache.label', 'Label'), 'child-new', 'new request receives current regional version');
is($new_chain->p('cache.parent', 'Parent label'), 'parent-only-new', 'new request receives current parent version');
is($chain->p('cache.label', 'Label'), 'child-old', 'evicted live regional snapshot remains unchanged');
is($chain->p('cache.parent', 'Parent label'), 'parent-only-old', 'evicted live parent snapshot remains unchanged');
ok(defined($weak_child) && defined($weak_parent), 'both old chain catalogs stay alive for their request');
undef $chain;
ok(!defined($weak_child) && !defined($weak_parent), 'both evicted chain catalogs are collectable when the request completes');

write_catalog('recent', 'zz', 'sgn', catalog('zz', 'recent-anchor'));
my $recent = translator('recent');
churn('recent-noise', 'recent-noise', 7);
my $touched = translator('recent');
is(refaddr($touched->{catalogs}[0]), refaddr($recent->{catalogs}[0]), 'successful hit reuses the retained oldest candidate');
write_catalog('recent-extra', 'zz', 'sgn', catalog('zz', 'recent-extra'));
my $extra = translator('recent-extra');
my $after_touch = translator('recent');
is(refaddr($after_touch->{catalogs}[0]), refaddr($recent->{catalogs}[0]), 'successful hit refreshes MRU order rather than FIFO eviction');

done_testing;
