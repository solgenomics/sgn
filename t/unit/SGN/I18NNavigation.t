use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use File::Copy qw(copy);
use JSON::PP;
use URI;
use HTML::Mason::Interp;
use HTML::Parser;
use SGN::I18N;
{
    package Local::NavigationRequest;
    sub uri { URI->new('/search/stocks?tag=A%26B&lang=en') }
    package Local::NavigationContext;
    use Moose;
    has config => (is=>'ro');
    has translator => (is=>'ro');
    has stash => (is=>'ro',default=>sub{{}});
    sub req { bless {}, 'Local::NavigationRequest' }
    sub i18n { $_[0]->translator }
    with 'SGN::Role::Site::I18N';
}
my $tmp = tempdir(CLEANUP=>1);
my $root = File::Spec->rel2abs('.');
sub save {
    my ($path,$text)=@_; my $dir=$path; $dir=~s{/[^/]+$}{}; make_path($dir);
    open my $out,'>:encoding(UTF-8)',$path or die $!; print {$out} $text; close $out;
}
for my $file ('site/toolbar.mas','site/toolbar/about.mas','site/toolbar/login.mas','i18n/language_selector.mas') {
    my $target="$tmp/comp/$file"; my $dir=$target; $dir=~s{/[^/]+$}{}; make_path($dir);
    copy("$root/mason/$file",$target) or die $!;
}
for my $part ('search_menu','manage','analyze','search','logo_and_name') {
    save("$tmp/comp/site/toolbar/$part.mas", $part eq 'logo_and_name' ? '<a class="navbar-brand">Breedbase</a>' : '<li><a href="/">Menu</a></li>');
}
open my $in,'<:raw','t/unit/SGN/i18n-fixtures.json' or die $!;
my $fixtures=JSON::PP->new->utf8->decode(do{local $/;<$in>}); close $in;
for my $locale (qw(uk ar)) {
    make_path("$tmp/catalog/$locale");
    open my $out,'>:raw',"$tmp/catalog/$locale/sgn.json" or die $!;
    print {$out} JSON::PP->new->utf8->encode($fixtures->{catalogs}{$locale}); close $out;
}
my $catalogs=$ENV{I18N_TEST_CATALOG_ROOT} || "$tmp/catalog";
for my $locale (qw(en uk es ar)) {
    my $translator=SGN::I18N->new(locale=>$locale,catalog_root=>$catalogs);
    my $c=Local::NavigationContext->new(config=>{i18n_enabled=>1,require_login=>0,
        i18n_enabled_locales=>'en,uk,es,ar',i18n_catalog_dir=>$catalogs,i18n_manual_locales=>'en,uk,es,ar'},translator=>$translator);
    my $html='';
    my $interp=HTML::Mason::Interp->new(comp_root=>"$tmp/comp",data_dir=>"$tmp/cache",allow_globals=>['$c'],
        preamble=>'use utf8;',autohandler_name=>'__unit_no_autohandler__',out_method=>\$html);
    $interp->set_global('$c',$c); $interp->exec('/site/toolbar.mas');
    my ($form,$select,$login,$return_to,@ids,@manual);
    my $index=0;
    my $parser=HTML::Parser->new(api_version=>3,start_h=>[sub{
        my($tag,$attr)=@_; ++$index;
        $form=$index if $tag eq 'form' && ($attr->{action}||'') eq '/i18n/language';
        $select=$index if ($attr->{id}||'') eq 'sgn-language';
        $login=$index if ($attr->{id}||'') eq 'login_button_html_div';
        $return_to=$attr->{value} if ($attr->{name}||'') eq 'return_to';
        push @manual,$attr->{href} if $tag eq 'a' && ($attr->{href}||'') =~ m{solgenomics.github.io/sgn};
    },'tagname,attr']); $parser->parse($html); $parser->eof;
    ok($form && $select && $login && $select<$login, "$locale: real selector precedes real login control");
    is($return_to,'/search/stocks?tag=A%26B&lang=en',"$locale: form retains query bytes at HTML boundary");
    is(scalar @manual,1,"$locale: one manual destination");
    if(my $evidence=$ENV{I18N_UI_EVIDENCE}) {
        my $document='<!doctype html><html lang="'.$translator->locale.'" dir="'.$translator->dir.'" data-sgn-locale="'.$locale.'"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head><body>'.$html.'<main><h1>Breedbase</h1><input id="field-notes" value="Synthetic field notes"></main></body></html>';
        save("$evidence/$locale.html",$document);
    }
}
done_testing;
