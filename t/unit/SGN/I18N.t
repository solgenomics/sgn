package main;
use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Basename qw(dirname);
use JSON::PP;
use POSIX qw(setlocale LC_ALL);
use SGN::I18N;

my $json = JSON::PP->new->utf8;
my $fixtures_path = dirname(__FILE__) . '/i18n-fixtures.json';
open my $fixture_file, '<:raw', $fixtures_path or die $!;
my $fixtures = do { local $/; $json->decode(<$fixture_file>) };
close $fixture_file;
my $catalog_root = tempdir(CLEANUP => 1);
sub write_catalog {
    my ($locale, $catalog) = @_;
    make_path("$catalog_root/$locale");
    open my $file, '>:raw', "$catalog_root/$locale/sgn.json" or die $!;
    print {$file} $json->encode($catalog);
    close $file;
}
write_catalog($_, $fixtures->{catalogs}{$_}) for keys %{$fixtures->{catalogs}};
sub translator { return SGN::I18N->new(locale => $_[0], catalog_root => $catalog_root); }
sub dies_like {
    my ($callback, $pattern, $label) = @_;
    my $ok = eval { $callback->(); 1 };
    ok(!$ok && $@ =~ $pattern, $label) or diag($@ || 'No exception');
}

my %env_before = %ENV;
my $process_locale = setlocale(LC_ALL);
my $uk = translator('UK-ua');
my $ar = translator('ar');
my $en = translator('en');
is($uk->requested_locale, 'uk-UA', 'locale tag is normalized');
is($uk->locale, 'uk', 'uninstalled region falls back to installed parent');
is($uk->dir, 'ltr', 'Ukrainian direction');
is($ar->dir, 'rtl', 'Arabic direction');
is(translator('zz')->locale, 'en', 'unknown installed language falls back to English');
is($en->p('controls.save', 'Save'), 'Save', 'English works with no English catalog');
is($uk->p('controls.save', 'Save'), 'Зберегти', 'Ukrainian UI translation');
is($uk->p('seedlots.save', 'Save'), 'Зберегти партію', 'identical English is distinguished by context');
is($uk->p('', 'Save'), 'Зберегти без контексту', 'empty gettext context supported');
is($uk->p('data', 'Wheat'), 'Wheat', 'unregistered scientific name unchanged');
is($uk->p('controls.save', 'Save changes'), 'Save changes', 'changed English source falls back');

my %uk_suffix = (0 => 'дослідів', 1 => 'дослід', 2 => 'досліди', 5 => 'дослідів', 11 => 'дослідів', 21 => 'дослід', 22 => 'досліди', 25 => 'дослідів', 101 => 'дослід');
for my $n (sort {$a <=> $b} keys %uk_suffix) {
    is($uk->np('trials.count', '%{count} trial found', '%{count} trials found', $n, {count => $n}), "Знайдено $n $uk_suffix{$n}", "Ukrainian plural $n");
}
for my $pair ([0,0], [1,1], [2,2], [3,3], [11,4], [100,5], [102,5]) {
    is($ar->np('trials.count', '%{count} trial found', '%{count} trials found', $pair->[0], {count => $pair->[0]}), "ar[$pair->[1]] $pair->[0]", "Arabic plural $pair->[0]");
}
is(translator('pt-BR')->np('trials.count','%{count} trial found','%{count} trials found',0,{count=>0}), 'pt-BR[0] 0', 'Brazil regional plural');
is(translator('pt-PT')->np('trials.count','%{count} trial found','%{count} trials found',0,{count=>0}), 'pt-PT[1] 0', 'Portugal regional plural differs');
is($uk->np('missing', '%{count} trial', '%{count} trials', 21, {count=>21}), '21 trials', 'English fallback uses English grammar');
is($uk->np('trials.count','%{count} trial found','%{count} records found',1,{count=>1}), '1 trial found', 'stale plural msgid falls back as whole message');

my $name = q{</script><img src=x onerror=alert(1)>};
is($uk->p('trial.named','Created trial %{name}.',{name=>$name}), "Створено дослід $name.", 'named data stays plain text for sink escaping');
for (1..5) {
    is($uk->p('controls.save','Save'), 'Зберегти', 'interleaved Ukrainian request');
    is($en->p('controls.save','Save'), 'Save', 'interleaved English request');
    is($ar->np('trials.count','%{count} trial found','%{count} trials found',3,{count=>3}), 'ar[3] 3', 'interleaved Arabic request');
}
is_deeply(\%ENV, \%env_before, 'runtime does not mutate environment');
is(setlocale(LC_ALL), $process_locale, 'runtime does not mutate process locale');
my $export = $uk->browser_catalog;
is($export->{locale},'uk','browser bootstrap locale');
$export->{catalogs}[0]{messages}{"controls.save\x04Save"}{forms}[0] = 'modified';
is($uk->p('controls.save','Save'), 'Зберегти', 'export cannot mutate shared catalog');
is_deeply($uk->export_catalog, $uk->browser_catalog, 'export alias matches browser payload');

dies_like(sub { $uk->p('trial.named','Created trial %{name}.',{}) }, qr/Missing or invalid named variable/, 'missing named variable rejected');
dies_like(sub { translator('../../secret') }, qr/Invalid locale/, 'locale cannot traverse directories');
for my $bad (-1, 1.2, undef, 'nan', '9007199254740992') {
    dies_like(sub { $uk->np('trials.count','one','many',$bad,{}) }, qr/Plural count/, 'invalid plural count rejected');
}
my $bad = $json->decode($json->encode($fixtures->{catalogs}{uk}));
$bad->{locale} = 'zz'; $bad->{pluralAst} = {type=>'EVAL',code=>'system("false")'};
write_catalog('zz',$bad);
dies_like(sub { translator('zz') },qr/Unsupported plural AST/,'catalog cannot supply executable AST nodes');
$bad->{pluralAst} = {type=>'MOD',left=>{type=>'VAR'},right=>{type=>'NUM',val=>0}};
write_catalog('zz',$bad);
dies_like(sub { translator('zz') },qr/division by zero/,'zero divisor rejected');
$bad = $json->decode($json->encode($fixtures->{catalogs}{uk}));
$bad->{locale}='zz'; $bad->{messages}{"controls.save\x04Save"}{forms}=[];
write_catalog('zz',$bad);
dies_like(sub { translator('zz') },qr/Incomplete catalog/,'incomplete message rejected before use');
is($en->p('literal', 'Keep {braces} and %{name}.', {name=>'value'}), 'Keep {braces} and value.', 'literal bare braces preserved');
is($en->p('literal', 'Value: %{name}', {name=>'%{other}'}), 'Value: %{other}', 'parameters substituted once without recursion');
my $logical = $json->decode($json->encode($fixtures->{catalogs}{'pt-PT'}));
$logical->{locale}='zz';
$logical->{pluralForms}='nplurals=2; plural=(n || 0);';
$logical->{pluralAst}={type=>'OR',left=>{type=>'VAR'},right=>{type=>'NUM',val=>0}};
write_catalog('zz',$logical);
my $logic_translator=translator('zz');
is($logic_translator->np('trials.count','%{count} trial found','%{count} trials found',3,{count=>3}), 'pt-PT[1] 3', 'GNU OR returns boolean index rather than operand');
$logical->{pluralForms}='nplurals=2; plural=(n && 5);';
$logical->{pluralAst}={type=>'AND',left=>{type=>'VAR'},right=>{type=>'NUM',val=>5}};
write_catalog('zz',$logical);
is(translator('zz')->np('trials.count','%{count} trial found','%{count} trials found',3,{count=>3}), 'pt-PT[1] 3', 'GNU AND returns boolean index rather than operand');
make_path("$catalog_root/ab");
open my $duplicate,'>:raw',"$catalog_root/ab/sgn.json" or die $!;
print {$duplicate} $json->encode($fixtures->{catalogs}{uk});close $duplicate;
dies_like(sub{translator('ab')},qr/locale mismatch/,'cached identical catalog still validates expected directory locale');

is($en->language_name, 'English', 'source language has a native name without a pack');
is($uk->language_name, 'uk', 'legacy catalogs without native-name metadata remain valid');
my $named = $json->decode($json->encode($fixtures->{catalogs}{uk}));
$named->{locale}='zz'; $named->{languageName}='Українська';
write_catalog('zz',$named);
is(translator('zz')->language_name,'Українська','native name comes from catalog data');
is(translator('zz')->browser_catalog->{languageName},'Українська','bootstrap preserves native-name Unicode');
for my $invalid ('', "bad\nname", 'x'x201, "bad\x85name", ['name']) {
    $named->{languageName}=$invalid; write_catalog('zz',$named);
    dies_like(sub{translator('zz')},qr/native language name/,'invalid native name rejected');
}


is(SGN::I18N::translate(undef, 'missing', 'Error: %{error}', {error => 'original'}),
    'Error: original', 'shared helper formats the English fallback');
is(SGN::I18N::translate($uk, 'controls.save', 'Save'), 'Зберегти', 'shared helper uses the request translator');
is(SGN::I18N::translate(undef), undef, 'absent request has no translator');
is(SGN::I18N::translate($en, 'html', 'A &amp; B <tag>', undef,
    {entities => '<>&', decode => 1}), 'A &amp; B &lt;tag&gt;', 'existing entity decoding and mask preserved');
is(SGN::I18N::translate($en, 'html', 'A &amp; B', undef,
    {entities => '<>&', decode => 0}), 'A &amp;amp; B', 'raw entity encoding remains distinct');
for my $n (1, 2, 21) {
    is(SGN::I18N::translate($uk, 'trials.count', '%{count} trial found', {count=>$n},
        {plural=>['%{count} trials found', $n]}),
        $uk->np('trials.count', '%{count} trial found', '%{count} trials found', $n, {count=>$n}),
        "shared helper preserves plural $n");
}
{
    package I18NStateProbe;
    sub i18n { $_ = 'changed'; $@ = 'changed'; $! = 13; return bless {}, __PACKAGE__; }
    sub p { $_ = 'changed'; $@ = 'changed'; $! = 13; return $_[2]; }
}
for my $action ('acquire', 'translate') {
    local $_ = 'caller';
    local $@ = 'previous exception';
    local $! = 2;
    my $error_number = 0 + $!;
    my $probe = bless {}, 'I18NStateProbe';
    my $result = $action eq 'acquire' ? SGN::I18N::translate($probe)
        : SGN::I18N::translate($probe, 'guard', 'English');
    my ($topic, $exception, $number) = ($_, $@, 0 + $!);
    is($topic, 'caller', "$action preserves caller topic");
    is($exception, 'previous exception', "$action preserves caller exception");
    is($number, $error_number, "$action preserves caller errno");
}

is(SGN::I18N::translate(undef, 'legacy.caption', 'Name: %{name}',
    {name => '__CAPTION_NAME__'}, {fallback => "Name: $name"}),
    "Name: $name", 'nullable legacy caption keeps original data without exposing substitution tokens');


my $bundle_root = tempdir(CLEANUP => 1);
my $bundle_directory = "$bundle_root/uk/sgn";
make_path($bundle_directory);
my @bundle_parts;
for my $spec (['common', "controls.save\x04Save"],
              ['trial_card', "trials.count\x04%{count} trial found"],
              ['seedlots', "seedlots.save\x04Save"]) {
    my ($group, $key) = @$spec;
    my $catalog = $json->decode($json->encode($fixtures->{catalogs}{uk}));
    $catalog->{messages} = {$key => $catalog->{messages}{$key}};
    my $bytes = $json->encode($catalog);
    open my $file, '>:raw', "$bundle_directory/$group.json" or die $!;
    print {$file} $bytes; close $file;
    push @bundle_parts, {name => $group, sha256 => Digest::SHA::sha256_hex($bytes)};
}
my $index_bytes = $json->encode({schema => 1, domain => 'sgn', sourceRevision => ('b' x 64), partitions => \@bundle_parts});
open my $index_file, '>:raw', "$bundle_directory/index.json" or die $!;
print {$index_file} $index_bytes; close $index_file;
my $partitioned = SGN::I18N->new(locale => 'uk-UA', catalog_root => $bundle_root);
is($partitioned->p('seedlots.save', 'Save'), 'Зберегти партію', 'Perl sees every bounded section');
my $native_export = $partitioned->export_catalog;
is(scalar @{$native_export->{catalogs}}, 1, 'native export keeps one merged catalog per locale');
is($native_export->{catalogs}[0]{sourceRevision}, 'b' x 64, 'native export retains the full bundle source revision');
ok(exists($native_export->{catalogs}[0]{messages}{"seedlots.save\x04Save"}), 'native export retains every server workflow');
my $browser = $partitioned->browser_catalog('trial_card');
is(scalar @{$browser->{catalogs}}, 2, 'browser receives common and its own section only');
ok(!grep({exists($_->{messages}{"seedlots.save\x04Save"})} @{$browser->{catalogs}}), 'unrelated workflow is absent from browser payload');
is($browser->{locale}, 'uk', 'section preserves regional parent fallback');
$browser->{catalogs}[0]{messages}{"controls.save\x04Save"}{forms}[0] = 'changed';
is($partitioned->p('controls.save', 'Save'), 'Зберегти', 'browser payload cannot mutate bundle cache');
my $unknown = $partitioned->browser_catalog('../../unknown');
is($unknown->{locale}, 'en', 'unknown section uses English');
is_deeply($unknown->{catalogs}, [], 'unknown section cannot select an arbitrary file');
unlink "$bundle_directory/trial_card.json" or die $!;
my $missing = SGN::I18N->new(locale => 'uk', catalog_root => $bundle_root);
is($missing->browser_catalog('trial_card')->{locale}, 'en', 'missing section uses English instead of full catalog');
is($partitioned->np('trials.count', '%{count} trial found', '%{count} trials found', 2, {count=>2}), 'Знайдено 2 досліди', 'active request keeps its immutable missing-file snapshot');
open my $corrupt, '>:raw', "$bundle_directory/common.json" or die $!;
print {$corrupt} '{}'; close $corrupt;
dies_like(sub { SGN::I18N->new(locale=>'uk', catalog_root=>$bundle_root) }, qr/hash mismatch/, 'changed partition bytes are checked before a cache hit');
open my $oversized, '>:raw', "$bundle_directory/common.json" or die $!;
print {$oversized} 'x' x (2*1024*1024+1); close $oversized;
dies_like(sub { SGN::I18N->new(locale=>'uk', catalog_root=>$bundle_root) }, qr/Oversized/, 'per-partition two MiB loader ceiling is unchanged');
my $source_map = "$bundle_root/workflows.json";
open my $mapping_file, '>:raw', $source_map or die $!;
print {$mapping_file} $json->encode({schema=>1, source_workflows=>{
    'cgi-bin/maps/vector.pl'=>'transformation', 'mason/trial/card.mas'=>'trial_card',
    'mason/page/default.mas'=>'global'}}); close $mapping_file;
is(SGN::I18N::workflow_for_source($source_map, '/maps/vector.pl', '/page/default.mas'), 'transformation', 'actual CGI source wins over generic page wrapper');
is(SGN::I18N::workflow_for_source($source_map, '/breeders/trial/1', '/trial/card.mas', '/page/default.mas'), 'trial_card', 'actual controller template wins over generic Mason base');
is(SGN::I18N::workflow_for_source($source_map, '/unknown', '/unknown.mas'), undef, 'unassigned source has no guessed workflow');

is(SGN::I18N::translate(translator('en'), 'helper.literal', 'A & "B"', undef, {entities => ''}),
    'A & "B"', 'explicit empty escape set preserves original literal bytes');
is(SGN::I18N::translate(translator('en'), 'helper.literal', 'A & "B"', undef, {entities => undef}),
    'A &amp; &quot;B&quot;', 'undefined escape set retains HTML::Entities default behavior');

done_testing;
