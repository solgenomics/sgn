=head1 NAME

t/unit/SGN/AccountTransport.t - preserve upstream credential transport on translated forms

=head1 DESCRIPTION

Exercise the actual POST guards and rendered browser handlers with isolated
request and persistence captures. No database, account, session or email is
created. These assertions qualify transport preservation, not complete CSRF
protection or full HTTP login acceptance.

=cut

package main;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use FindBin;
use JSON::PP;
use Catalyst::Response;
use HTML::Mason::Interp;
use SGN::I18N;
use SGN::Controller::AJAX::User;

# Invoke actual controller guards and rendered form handlers. Database, account
# and mail dependencies are capture-only; these tests create no real account.
{
    package Local::AccountTransport::Request;
    sub method { $_[0]{method} }
    sub param { $_[0]{reads}++; $_[0]{params}{$_[1]} }
    sub params { $_[0]{reads}++; $_[0]{params} }
    sub body_parameters { $_[0]{reads}++; $_[0]{params} }
    sub referer { '/fixture' }
    package Local::AccountTransport::Database;
    sub dbh { $_[0] }
    package Local::AccountTransport::Login;
    sub login_user { $_[0]{state}{login_calls}++; return {incorrect_password => 1}; }
    package Local::AccountTransport::Context;
    sub new {
        my ($class, $method) = @_;
        my $state = {login_calls => 0};
        return bless {
            request => bless({method => $method, reads => 0, params => {
                username => 'fixtureuser', password => 'synthetic-password', goto_url => '/fixture',
                new_password => 'short', confirm_password => 'short', token => 'SyntheticToken12',
            }}, 'Local::AccountTransport::Request'),
            state => $state, database => bless({state => $state}, 'Local::AccountTransport::Database'),
            response => Catalyst::Response->new, stash => {}, config => {is_mirror => 1},
            translator => SGN::I18N->new(locale => 'en'), db_calls => 0,
        }, $class;
    }
    sub req { $_[0]{request} }
    sub res { $_[0]{response} }
    sub stash { $_[0]{stash} }
    sub config { $_[0]{config} }
    sub get_conf { undef }
    sub i18n { $_[0]{translator} }
    sub user { undef }
    sub dbic_schema { $_[0]{database} }
    sub dbc { $_[0]{db_calls}++; $_[0]{database} }
    sub detach { die "fixture detach\n"; }
}
my $controller = SGN::Controller::AJAX::User->new;
my @actions = qw(login new_account change_account_info_action quick_create_user process_reset_password_form);
subtest 'all credential-changing actions retain upstream POST-only rejection' => sub {
    for my $action (@actions) {
        for my $method (qw(GET HEAD PUT)) {
            my $c = Local::AccountTransport::Context->new($method);
            my $ok = eval { $controller->$action($c); 1 };
            ok($ok, "$action/$method returns through its native guard") or diag $@;
            is($c->res->status, 405, "$action/$method has native status");
            is($c->res->header('Allow'), 'POST', "$action/$method declares POST");
            is($c->stash->{rest}{error}, 'This request must be sent using POST.', "$action/$method retains upstream diagnostic");
            is($c->req->{reads}, 0, "$action/$method never reads credentials or reset tokens");
            is($c->{db_calls}, 0, "$action/$method never enters account processing through dbc");
        }
    }
};
subtest 'POST still reaches existing login, permission and validation branches' => sub {
    no warnings 'redefine';
    local *CXGN::Login::new = sub { bless {state => $_[1]{state}}, 'Local::AccountTransport::Login' };
    my $c = Local::AccountTransport::Context->new('POST');
    $controller->login($c);
    is($c->{state}{login_calls}, 1, 'POST reaches the captured credential checker');
    like($c->stash->{rest}{error}, qr/Login credentials are incorrect/, 'POST retains login validation');
    for my $action (qw(change_account_info_action quick_create_user)) {
        $c = Local::AccountTransport::Context->new('POST');
        $controller->$action($c);
        like($c->stash->{rest}{error}, qr/logged in/i, "$action/POST retains login requirement");
        is($c->{db_calls}, 0, "$action/POST anonymous request cannot perform account work");
    }
    $c = Local::AccountTransport::Context->new('POST');
    $controller->new_account($c);
    is($c->stash->{template}, '/system_message.mas', 'POST reaches the existing mirror registration branch');
    $c = Local::AccountTransport::Context->new('POST');
    eval { $controller->process_reset_password_form($c); 1 };
    is($@, "fixture detach\n", 'POST reaches native short-password validation');
    like($c->stash->{rest}{error}, qr/Password is too short/, 'Reset validation remains intact');
    is($c->{db_calls}, 0, 'Rejected reset cannot reach account persistence');
};

my $root = File::Spec->rel2abs(File::Spec->catdir($FindBin::Bin, '..', '..', '..'));
my $tmp = tempdir(CLEANUP => 1);
sub save_text {
    my ($path, $text) = @_;
    my $parent = $path; $parent =~ s{/[^/]+$}{};
    make_path($parent);
    open my $out, '>:encoding(UTF-8)', $path or die $!;
    print {$out} $text; close $out;
}
sub read_text {
    open my $in, '<:encoding(UTF-8)', $_[0] or die $!;
    local $/; return <$in>;
}
my @views = (
    ['login', 'site/login_dialog.mas', {}],
    ['change', 'user/change_account.mas', {logged_in_username => 'fixtureuser'}],
    ['quick', 'user/quick_create_account.mas', {}],
    ['reset', 'user/reset_password_form.mas', {person_id => 41, username => 'fixtureuser', token => 'SyntheticToken12'}],
);
my @rendered;
save_text("$tmp/comp/page/page_title.mas", '<%args>$title</%args><h1><% $title %></h1>');
for my $view (@views) {
    my ($name, $path, $arguments) = @$view;
    save_text("$tmp/comp/$name.mas", read_text("$root/mason/$path"));
    my $html = '';
    my $interp = HTML::Mason::Interp->new(
        comp_root => "$tmp/comp", data_dir => "$tmp/cache", allow_globals => ['$c'],
        preamble => 'use utf8;', autohandler_name => '__fixture_no_autohandler__', out_method => \$html,
    );
    $interp->set_global('$c', Local::AccountTransport::Context->new('GET'));
    $interp->exec("/$name.mas", %$arguments);
    my @scripts = $html =~ m{<script\b[^>]*>([\s\S]*?)</script>}g;
    push @rendered, {name => $name, script => join("\n", @scripts)};
}
save_text("$tmp/rendered.json", JSON::PP->new->encode(\@rendered));
save_text("$tmp/handlers.cjs", <<'JAVASCRIPT');
'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const I18N=require(process.argv[2]);
const views=JSON.parse(fs.readFileSync(process.argv[3],'utf8'));
const expected={login:[['#new_account_form','submit','/ajax/user/new'],['#login_form','submit','/ajax/user/login']],change:[['#change_account_form','submit','/ajax/user/update']],quick:[['#create_account','click','/ajax/user/quick_create_account']],reset:[['#process_reset_password_form','submit','/ajax/user/process_reset_password']]};
const result=[];
for(const view of views){
 const handlers=new Map(),calls=[],modals=[],alerts=[];
 const payload='username=fixtureuser&password=synthetic-password&tag=A%26B&token=SyntheticToken12';
 const challenge=/if \( response !== "([0-9]+)" \)/.exec(view.script);
 const jq=selector=>({
  ready(callback){callback();return this;},
  submit(callback){handlers.set(selector+':submit',callback);return this;},
  click(callback){handlers.set(selector+':click',callback);return this;},
  on(){return this;},change(){return this;},keydown(){return this;},off(){return this;},
  appendTo(){return this;},focus(){return this;},prop(){return this;},
  modal(value){modals.push([selector,value]);return this;},
  serialize(){return payload;},
  val(){return selector==="input[name='challenge_response']"?challenge[1]:'fixture-value';}
 });
 jq.ajax=options=>calls.push(options);
 const sandbox={jQuery:jq,document:{documentElement:{lang:'uk',getAttribute(){return 'uk-UA';}},getElementById(){return {type:'password'};}},window:{location:{href:'https://fixture.invalid/user/login'}},URL,console,alert:value=>alerts.push(value)};
 vm.createContext(sandbox);I18N.install(sandbox);sandbox.window.SGN=sandbox.SGN;
 vm.runInContext(view.script,sandbox,{filename:view.name+'.mas'});
 for(const [selector,event,url]of expected[view.name]){
  let prevented=0;const before=calls.length;
  const handler=handlers.get(selector+':'+event);assert.equal(typeof handler,'function',view.name+' native handler');
  handler({preventDefault(){prevented++;}});assert.equal(calls.length,before+1);
  const call=calls.at(-1);assert.equal(call.url,url);assert.equal(call.method||call.type,'POST');assert.equal(call.data,payload);assert(!call.url.includes('password='));
  if(view.name==='login'||view.name==='reset')assert.equal(call.headers['X-SGN-Locale'],'uk-UA');
  if(event==='submit')assert.equal(prevented,1);
  if(url==='/ajax/user/new'){
   call.beforeSend();call.error({responseJSON:{error:'fixture failure'}});
   assert.deepEqual(modals.slice(-2),[['#working_modal','show'],['#working_modal','hide']]);
   assert.equal(alerts.at(-1),'Could not create new account. Please try again later. [fixture failure]');
  }
  result.push({url,method:call.method||call.type,opaqueFormDataPreserved:true,localeHeader:call.headers?.['X-SGN-Locale']||null});
 }
}
console.log(JSON.stringify(result));
JAVASCRIPT
subtest 'actual rendered form handlers use POST and retain fields and locale headers' => sub {
    open my $node, '-|', 'node', "$tmp/handlers.cjs", "$root/static/js/sgn-i18n.js", "$tmp/rendered.json" or die $!;
    my $output = do { local $/; <$node> };
    close $node;
    my $status = $?;
    is($status, 0, 'Real rendered JS handlers satisfy transport and failure-cleanup contracts');
    return if $status;
    my $calls = JSON::PP->new->decode($output);
    is(scalar @$calls, 5, 'Login, registration, account change, quick create and reset handlers exercised');
};
done_testing;
