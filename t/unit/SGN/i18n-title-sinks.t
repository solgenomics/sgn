package main;
use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use FindBin;
use JSON::PP;
use HTML::Entities qw(decode_entities);
use HTML::Mason::Interp;
use HTML::Parser;
use SGN::I18N;

# Render the actual consent view and actual title/section call sites. Unrelated
# workflow bodies are controlled; no controller, login, model or analysis runs.
my $root = File::Spec->rel2abs(File::Spec->catdir($FindBin::Bin, '..', '..', '..'));
my $tmp = tempdir(CLEANUP => 1);
sub read_text {
    open my $fh, '<:encoding(UTF-8)', $_[0] or die $!;
    local $/; return <$fh>;
}
sub save_text {
    my ($path, $text) = @_;
    my $dir = $path; $dir =~ s{/[^/]+$}{};
    make_path($dir);
    open my $fh, '>:encoding(UTF-8)', $path or die $!;
    print {$fh} $text; close $fh;
}
sub section_call {
    my ($relative, $context) = @_;
    my $source = read_text("$root/$relative");
    my @calls = $source =~ /(<&\|\s*\/page\/info_section\.mas\b[\s\S]*?&>)/g;
    my ($call) = grep { index($_, $context) >= 0 } @calls;
    die "Missing actual section call: $relative $context" unless $call;
    return $call . '<p id="trusted-content">Controlled body</p></&>';
}
my @cases = (
    ['consent', read_text("$root/mason/brapi/authorize.mas")],
    ['reset', read_text("$root/mason/user/reset_password_form.mas")],
    ['section', section_call('mason/barcode/index.mas', 'barcode.mason.generate_barcode')],
    ['links', section_call('mason/tools/heritability/index.mas', 'analysis.interface.table_8675')],
);
my $propagation = read_text("$root/mason/propagation/propagation_project.mas");
my ($dynamic) = $propagation =~ /(<&\s*\/page\/page_title\.mas\b[\s\S]*?&>)/;
push @cases, ['dynamic', $dynamic];
for my $component ('page_title', 'info_section') {
    save_text("$tmp/comp/page/$component.mas", read_text("$root/mason/page/$component.mas"));
}
for my $case (@cases) { save_text("$tmp/comp/$case->[0].mas", $case->[1]); }
my $literal = '<img src=x onerror="window.injected=1"> & "caption"';
my $name = 'Name_Жито_<img src=x onerror="data">_%{name}_&lt;literal&gt;';
my %sources = (
    'integrations.consent.title' => 'BrAPI Client Authorization',
    'barcode.mason.generate_barcode' => 'Generate Barcode',
    'analysis.interface.table_8675' => 'Table&#8675;',
    'analysis.interface.basic_8675' => 'Basic&#8675;',
    'seedlot.details_for' => 'Details for ',
    'auth.reset.password_for_user' => 'Enter new password for user %{username}',
);
for my $locale (qw(uk es ar)) {
    my %messages = map {
        ($_ . "\x04" . $sources{$_}) => {plural => undef, forms => [$locale . ': ' . $literal . ($sources{$_} =~ /&#8675;/ ? '&#8675;' : '')
            . ($_ eq 'auth.reset.password_for_user' ? ' %{username}' : '')]}
    } keys %sources;
    make_path("$tmp/catalog/$locale");
    open my $out, '>:raw', "$tmp/catalog/$locale/sgn.json" or die $!;
    print {$out} JSON::PP->new->utf8->encode({
        schema => 1, api => 1, locale => $locale, direction => $locale eq 'ar' ? 'rtl' : 'ltr',
        nplurals => 1, pluralForms => 'nplurals=1; plural=0;',
        pluralAst => {type => 'NUM', val => 0}, messages => \%messages,
    }); close $out;
}
{
    package Local::TitleContext;
    sub i18n { $_[0]->{translator} }
}
for my $locale (qw(en uk es ar)) {
    my $translator = SGN::I18N->new(locale => $locale, catalog_root => "$tmp/catalog");
    my $c = bless {translator => $translator}, 'Local::TitleContext';
    for my $case (@cases) {
        subtest "$locale $case->[0]" => sub {
            my $html = '';
            my $interp = HTML::Mason::Interp->new(comp_root => "$tmp/comp", data_dir => "$tmp/cache",
                allow_globals => ['$c', '$trial_name'], preamble => 'use utf8; use HTML::Entities ();',
                autohandler_name => '__unit_no_autohandler__', out_method => \$html);
            $interp->set_global('$c', $c);
            $interp->set_global('$trial_name', $name);
            srand(714);
            $interp->exec("/$case->[0].mas", user_name => $name, client_id => $name,
                database_name => $name, username => HTML::Entities::encode_entities($name),
                person_id => 42, token => 'synthetic-token', authorize_url => '/native/authorize?token=synthetic&next=1', deny_url => '/native/deny');
            my (@bad, @anchors, @links, @texts, @ids);
            my $parser = HTML::Parser->new(api_version => 3,
                start_h => [sub {
                    my ($tag, $attr) = @_;
                    push @bad, $tag if exists $attr->{onerror} || ($tag eq 'img' && ($attr->{src} || '') eq 'x');
                    push @anchors, $attr->{name} if $tag eq 'a' && defined $attr->{name};
                    push @links, $attr->{href} if $tag eq 'a' && defined $attr->{href};
                    push @ids, $attr->{id} if defined $attr->{id};
                }, 'tagname,attr'], text_h => [sub { push @texts, $_[0] }, 'dtext']);
            $parser->parse($html); $parser->eof;
            is_deeply(\@bad, [], 'Catalog/data text creates no image or executable attribute');
            my $text = join '', @texts;
            like($text, qr/\Q$locale: $literal\E/, 'Translated label is displayed literally') if $locale ne 'en';
            if ($case->[0] eq 'consent') {
                is_deeply(\@links, ['/native/authorize?token=synthetic&next=1', '/native/deny'], 'Original consent destinations and query data retained');
                like($text, qr/\Q$name\E/, 'User/client/database name remains literal data');
            } elsif ($case->[0] eq 'section') {
                ok(grep($_ eq 'generate_barcode', @anchors), 'Canonical anchor stays English in every locale');
                ok(grep($_ eq 'trusted-content', @ids), 'Caller-owned body remains HTML');
            } elsif ($case->[0] eq 'links') {
                ok(grep($_ eq 'javascript:download_table();', @links), 'Original download control retained');
                like($text, qr/\x{21e3}/, 'Legacy numeric arrow entity retains its displayed symbol');
            } elsif ($case->[0] eq 'reset') {
                like($text, qr/\Q$name\E/, 'Pre-escaped username is displayed once and retains literal entities');
            } else {
                like($text, qr/\Q$name\E/, 'Dynamic title suffix remains literal Unicode/name data');
            }
            done_testing;
        };
    }
}
done_testing;
