use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON ();
use SGN::I18N;
my $root=tempdir(CLEANUP=>1);
make_path("$root/zz");
my $path="$root/zz/sgn.json";
sub write_bytes { open my $h,'>:raw',$path or die $!; print {$h} $_[0]; close $h; }
my $text="Українська العربية Español e\x{301} \x{1f33e} <script> %{name}";
my $pack={schema=>1,api=>1,locale=>'zz',direction=>'ltr',nplurals=>2,
 pluralForms=>'nplurals=2; plural=(n != 1);',
 pluralAst=>{type=>'NEQ',left=>{type=>'VAR'},right=>{type=>'NUM',val=>1}},
 messages=>{"label\x04Label"=>{plural=>undef,forms=>[$text]}}};
my $json=JSON->new->canonical->utf8;
write_bytes($json->encode($pack));
my $t=SGN::I18N->new(locale=>'zz',catalog_root=>$root);
is($t->p('label','Label',{name=>'SQ_2026'}),$text=~s/%\{name\}/SQ_2026/r,'Unicode and scientific parameter bytes stay intact');
my $copy=$t->browser_catalog;
like($json->encode($copy),qr/"nplurals":2(?:[,}])/,'browser plural count remains a JSON number');
$copy->{catalogs}[0]{messages}{"label\x04Label"}{forms}[0]='changed';
is($t->p('label','Label',{name=>'SQ_2026'}),$text=~s/%\{name\}/SQ_2026/r,'export remains an independent copy');
my $valid=$json->encode($pack);
my $invalid_utf8=$valid;
$invalid_utf8=~s/Label/\xff/;
my $invalid_surrogate=$valid;
$invalid_surrogate=~s/"forms":\["[^"]*"\]/"forms":["\\uD800"]/;
for my $bad ($invalid_utf8,$valid.' trailing','{broken}',$invalid_surrogate) {
 write_bytes($bad);
 my $ok=eval { SGN::I18N->new(locale=>'zz',catalog_root=>$root); 1 };
 ok(!$ok && $@ !~ /Unsupported catalog schema/,'malformed JSON is rejected before catalog validation') or diag($@ || 'No exception');
}
$pack->{messages}{"label\x04Label"}{forms}[0]='Поле العربية Español ' x 40000;
write_bytes($json->encode($pack));
my $large;
my $ok=eval { local $SIG{ALRM}=sub { die "catalog decode exceeded five seconds\n" }; alarm 5; $large=SGN::I18N->new(locale=>'zz',catalog_root=>$root); my $export=$large->browser_catalog; alarm 0; 1 };
alarm 0;
ok($ok,'a bounded UTF-8 catalog loads and exports within five seconds') or diag($@);
is(length($large->p('label','Label')),length($pack->{messages}{"label\x04Label"}{forms}[0]),'long text remains complete') if $ok;
done_testing;
