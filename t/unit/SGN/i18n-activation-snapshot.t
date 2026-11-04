use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP;
use Digest::SHA qw(sha256_hex);
use SGN::I18N;
my $root = tempdir(CLEANUP => 1);
my $json = JSON::PP->new->canonical->utf8;
for my $version (qw(old new)) {
    my $dir = "$root/$version/sgn";
    make_path($dir);
    my $bytes = $json->encode({schema=>1,api=>1,locale=>'zz',direction=>'ltr',nplurals=>1,
        pluralForms=>'nplurals=1; plural=0;',pluralAst=>{type=>'NUM',val=>0},
        messages=>{"label\x04Label"=>{plural=>undef,forms=>[$version]}}});
    open my $out, '>:raw', "$dir/common.json" or die $!; print {$out} $bytes; close $out;
    open $out, '>:raw', "$dir/index.json" or die $!;
    print {$out} $json->encode({schema=>1,domain=>'sgn',partitions=>[{name=>'common',sha256=>sha256_hex($bytes)}]}); close $out;
}
make_path("$root/active");
my $link = "$root/active/zz";
symlink "$root/old", $link or die $!;
my $read = \&SGN::I18N::_bounded_bytes;
my ($old, $switched);
{
    no warnings 'redefine';
    local *SGN::I18N::_bounded_bytes = sub {
        my $bytes = $read->(@_);
        if (!$switched && $_[0] =~ /index\.json$/) {
            unlink $link or die $!; symlink "$root/new", $link or die $!; $switched = 1;
        }
        return $bytes;
    };
    $old = eval { SGN::I18N->new(locale=>'zz',catalog_root=>"$root/active") };
    is($@, '', 'Concurrent activation cannot mix one index with another generation');
}
ok($switched, 'Fixture switches the real active pointer immediately after index read');
is($old ? $old->p('label','Label') : undef, 'old', 'In-flight request retains the complete old catalog');
is(SGN::I18N->new(locale=>'zz',catalog_root=>"$root/active")->p('label','Label'), 'new', 'Next request sees the complete new catalog');
done_testing;
