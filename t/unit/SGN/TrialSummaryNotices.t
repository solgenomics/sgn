package main;
use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP;
use HTML::Entities qw(encode_entities);
use SGN::I18N;
use SGN::Controller::BreedersToolbox::Trial;

# Actual early controller branches with memory-only schemas/requests/response
# and captured dependency construction. No database or auth-policy change.
my %source = (missing => 'The requested trial (%{trial_id}) does not exist', deleted => 'The requested trial does not exist or has been deleted.');
my %prefix = (en => '', uk => 'Українська: ', es => 'Español: ', ar => 'العربية: ');
my $root=tempdir(CLEANUP=>1);
for my $locale (qw(uk es ar)) {
    make_path("$root/$locale");
    my %messages=map {("trial.summary.notice.$_\x04$source{$_}"=>{plural=>undef,forms=>[$prefix{$locale}.$source{$_}.' <img src=x>']})} keys %source;
    open my $out,'>:raw',"$root/$locale/sgn.json" or die $!;
    print {$out} JSON::PP->new->utf8->encode({schema=>1,api=>1,locale=>$locale,direction=>$locale eq 'ar'?'rtl':'ltr',sourceRevision=>'0'x64,
        nplurals=>1,pluralForms=>'nplurals=1; plural=0;',pluralAst=>{type=>'NUM',val=>0},messages=>\%messages});close $out;
}
{
    package Local::TrialSummaryNotices::Context;
    sub new { bless {translator=>$_[1],stash=>{trial_id=>$_[2]},queries=>[],exists_calls=>[],authenticated=>$_[3]},$_[0] }
    sub i18n { $_[0]->{translator} } sub stash { $_[0]->{stash} } sub req { $_[0] }
    sub param { undef } sub uri { require URI;URI->new('/breeders/trial/137?lang=uk') }
    sub res { $_[0] } sub redirect { $_[0]->{redirect}=$_[1] }
    sub user { $_[0]->{authenticated} ? bless({},'Local::TrialSummaryNotices::User') : undef }
    sub dbic_schema { push @{$_[0]->{queries}},[@_[1..$#_]];bless {},'Local::TrialSummaryNotices::Schema' }
    sub dbc { die 'Real database access is forbidden in this early-branch test' }
    package Local::TrialSummaryNotices::User;
    sub check_roles { 0 }
    package Local::TrialSummaryNotices::Program;
    sub trial_exists { push @{$_[0]->{context}{exists_calls}},$_[1];0 }
}
my $controller=SGN::Controller::BreedersToolbox::Trial->new;
my $id='137_Опис_العربية <img src=x> & literal';
for my $locale (qw(en uk es ar)) {
    subtest "$locale preserves early notice branch contracts"=>sub {
        my $c=Local::TrialSummaryNotices::Context->new(SGN::I18N->new(locale=>$locale,catalog_root=>$root),$id,1);
        {
            no warnings qw(redefine once);
            local *CXGN::Trial::new=sub {die "Synthetic nonexistent trial\n"};
            $controller->trial_init($c,$id);
        }
        is($c->stash->{trial_id},$id,'Original trial identifier reaches stash unchanged');
        is($c->stash->{template},'system_message.txt','Original legacy template selection retained, including its known route limitation');
        my $text=$prefix{$locale}.$source{missing}.($locale eq 'en'?'':' <img src=x>');$text=~s/%\{trial_id\}/$id/g;
        is($c->stash->{message},encode_entities($text),'Whole missing notice and arbitrary identifier are escaped once');
        is_deeply($c->{queries},[['Bio::Chado::Schema']],'Original early schema request retained, without actual connection');
        $c=Local::TrialSummaryNotices::Context->new(SGN::I18N->new(locale=>$locale,catalog_root=>$root),137,1);
        {
            no warnings qw(redefine once);
            local *CXGN::BreedersToolbox::Projects::new=sub {bless {context=>$c},'Local::TrialSummaryNotices::Program'};
            $controller->trial_info($c);
        }
        is($c->stash->{template},'generic_message.mas','Deleted/missing notice remains in the original HTML sink');
        $text=$prefix{$locale}.$source{deleted}.($locale eq 'en'?'':' <img src=x>');
        is($c->stash->{message},encode_entities($text),'Deleted/missing notice translated and safely preescaped');
        is_deeply($c->{exists_calls},[137],'Canonical project-existence lookup unchanged');
        $c=Local::TrialSummaryNotices::Context->new(SGN::I18N->new(locale=>$locale,catalog_root=>$root),137,0);
        $controller->trial_info($c);
        like($c->{redirect},qr{^/user/login\?goto_url=},'Anonymous users retain original login redirect before metadata access');
        is_deeply($c->{queries},[],'Anonymous branch still makes no metadata query');
        ok(!exists($c->stash->{message}),'Anonymous redirect does not become a public trial-existence notice');
    };
}
done_testing;
