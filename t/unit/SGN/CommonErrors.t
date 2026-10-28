package main;
use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use FindBin;
use JSON::PP;
use HTML::Entities qw(encode_entities);
use HTML::Mason::Interp;
use SGN::I18N;
use SGN::Exception;

# Real Mason templates and the real exception role with memory-only request,
# response, logger and view dependencies. No database, auth policy or mail writes.
my %source = (
    'common.error.title.server' => 'Server Error',
    'common.error.title.client' => 'Error',
    'common.error.title.message' => 'Message',
    'common.error.processing' => 'Our apologies, there was an error processing your request.',
    'common.error.report_sent' => 'An error report has been sent to the %{project_name} development team.',
    'common.error.contact.server' => 'Feel free to contact the %{development_team}, if the problem persists, and we will keep you informed of our progress in resolving it.',
    'common.error.contact.client' => 'Feel free to contact the %{development_team}, if the problem persists, and we will work with you to resolve it.',
    'common.error.development_team' => 'development team',
    'common.error.developer_message' => 'Developer message:',
    'common.error.no_developer_message' => 'none provided',
    'common.error.access_denied.title' => 'Access denied',
    'common.error.access_denied.message' => 'You do not have sufficient permissions to view this page. This could be due to your user status or server configuration. Contact a server administrator for more details.',
    'common.error.not_found.title' => '404 - not found',
    'common.error.not_found.resource' => 'Resource not found.',
    'common.error.not_found.message' => '%{message}  We apologize for the inconvenience.',
    'common.error.not_found.external_link' => 'If you reached this page from a link on another site, you may wish to inform them that the link is incorrect.',
    'common.error.contact.fallback' => 'Please also feel free to contact us at %{email} and inform us of the error, and we will keep you informed of our progress in resolving it.',
    'common.error.site_maintainers' => "this site's maintainers",
    'common.error.severe' => 'Our apologies, a severe error has occurred. Please contact %{contact_link} and report this error.',
);
my %prefix = (en => '', uk => 'Українська: ', es => 'Español: ', ar => 'العربية: ');
my $adverse = ' <img src=x onerror="unit()"> & "%{other}"';
my $catalog_root = tempdir(CLEANUP => 1);
my $json = JSON::PP->new->utf8->canonical;
for my $locale (qw(uk es ar)) {
    make_path("$catalog_root/$locale");
    my %messages = map {("$_\x04$source{$_}" => {plural => undef, forms => [$prefix{$locale}.$source{$_}.$adverse]})} keys %source;
    # No extra placeholder in the adverse translation: placeholders remain source-owned.
    for my $record (values %messages) { $record->{forms}[0] =~ s/\Q%{other}\E/literal/g }
    open my $out, '>:raw', "$catalog_root/$locale/sgn.json" or die $!;
    print {$out} $json->encode({schema => 1, api => 1, locale => $locale, direction => $locale eq 'ar' ? 'rtl' : 'ltr',
        sourceRevision => '0' x 64, nplurals => 1, pluralForms => 'nplurals=1; plural=0;', pluralAst => {type => 'NUM', val => 0}, messages => \%messages});
    close $out;
}
{
    package Local::CommonErrors::Response;
    sub new { bless {}, shift }
    sub status { $_[0]->{status} = $_[1] if @_ > 1; $_[0]->{status} }
    sub content_type { $_[0]->{content_type} = $_[1] if @_ > 1; $_[0]->{content_type} }
    sub body { $_[0]->{body} = $_[1] if @_ > 1; $_[0]->{body} }
    package Local::CommonErrors::View;
    sub new { bless {}, shift }
    sub process { push @{$_[1]->{renders}}, $_[1]->stash->{template}; !$_[1]->{fail_view} }
    package Local::CommonErrors::Context;
    use Moose;
    sub new {
        my ($class, $translator, %args) = @_;
        bless {translator => $translator, stash => {}, errors => [], res => Local::CommonErrors::Response->new,
            renders => [], forwards => [], logs => [], config => {production_server => 1}, %args}, $class;
    }
    sub i18n { $_[0]->{translator} }
    sub stash { my $self = shift; @{$self->{stash}}{keys %{$_[0]}} = values %{$_[0]} if @_; $self->{stash} }
    sub error { $_[0]->{errors} }
    sub clear_errors { $_[0]->{errors} = [] }
    sub res { $_[0]->{res} }
    sub view { Local::CommonErrors::View->new }
    sub forward { push @{$_[0]->{forwards}}, $_[1] }
    sub finalize_error { $_[0]->{original_finalizer_calls}++ }
    sub config { $_[0]->{config} }
    sub get_conf { $_[0]->{config}{$_[1]} }
    sub detach { die "memory-only detach\n" }
    sub req { $_[0] }
    sub referer { $_[0]->{referer} }
    sub uri_for { 'http://fixture.invalid/' }
    sub debug { $_[0]->{debug} || 0 }
    sub log { $_[0] }
    # Logger debug is the same method name as the context flag. Capture through
    # a separate object so logging never changes the context's debug setting.
    with 'SGN::Role::Site::Exceptions';
    package Local::CommonErrors::Logger;
    sub debug { push @{$_[0]->{context}{logs}}, $_[1] }
    package Local::CommonErrors::Captured404;
    use Moose;
    extends 'Local::CommonErrors::Context';
    sub throw { my $self = shift; $self->{throw} = {@_} }
    sub log { bless {context => $_[0]}, 'Local::CommonErrors::Logger' }
    package Local::CommonErrors::BrokenCatalog;
    use Moose;
    extends 'Local::CommonErrors::Context';
    sub i18n { die "Synthetic unavailable optional catalog\n" }

}
my $component_root = "$FindBin::Bin/../../../mason";
my $output;
my $interp = HTML::Mason::Interp->new(comp_root => $component_root, data_dir => tempdir(CLEANUP => 1),
    allow_globals => ['$c'], preamble => 'use utf8;', out_method => \$output, autohandler_name => '__unit_no_autohandler__');
sub translator { SGN::I18N->new(locale => $_[0], catalog_root => $catalog_root) }
sub context { Local::CommonErrors::Context->new(translator($_[0]), @_[1..$#_]) }
sub render {
    my ($context, $component, %args) = @_;
    $output = '';
    $interp->set_global('$c', $context);
    $interp->exec($component, %args);
    return $output;
}
my $caller_html = '<b class="legacy-title">Сорт_已更新_العربية &amp; data</b>';
my $caller_message = '<a href="/search/markers?name=literal%3Ctag%3E">Unicode Опис_العربية</a><br />Names <em>stay data</em>';
my $developer = 'Private Unicode Опис_العربية <img src=x> & detail';
for my $locale (qw(en uk es ar)) {
    subtest "$locale source-owned text and legacy HTML" => sub {
        my $c = context($locale);
        is($c->i18n->locale, $locale, 'Requested real language catalog loaded');
        my $e = SGN::Exception->new(title => $caller_html, public_message => $caller_message, developer_message => $developer,
            is_client_error => 1, notify => 0, http_status => 418);
        my $html = render($c, '/site/error/exception.mas', exception => $e, show_dev_message => 0, project_name => '<img src=x>');
        like($html, qr/\Q$caller_html\E/, 'Legacy caller title HTML and Unicode retained');
        like($html, qr/\Q$caller_message.\E/, 'Legacy caller message HTML and original period policy retained');
        unlike($html, qr/\Q$developer\E|Private Unicode/, 'Diagnostics excluded when disabled');
        unlike($html, qr/An error report/, 'notify=false preserves absent notification notice');
        like($html, qr/<a href="\/contact\/form">/, 'Fixed contact destination retained');
        unlike($html, qr/<img\b/, 'All owned translations and display variables escaped');
        my $shown = render($c, '/site/error/exception.mas', exception => $e, show_dev_message => 1);
        like($shown, qr/\Q@{[encode_entities($developer)]}\E/, 'Enabled diagnostics remain escaped original text');
        is($e->http_status, 418, 'Rendering never changes exception status');
        for my $case (
            ['server', {is_server_error => 1, notify => 1}, 'server'],
            ['client', {is_client_error => 1, notify => 0}, 'client'],
            ['message', {is_client_error => 0, is_server_error => 0, notify => 0}, undef],
        ) {
            my ($key, $args, $contact) = @$case;
            my $error = SGN::Exception->new(%$args);
            $html = render($c, '/site/error/exception.mas', exception => $error, project_name => 'Site <img src=x>');
            my $title = $c->i18n->p("common.error.title.$key", $source{"common.error.title.$key"});
            like($html, qr/\Q@{[encode_entities($title)]}\E/, 'Default title translated and escaped');
            my $processing = $c->i18n->p('common.error.processing', $source{'common.error.processing'});
            like($html, qr/\Q@{[encode_entities($processing)]}\E/, 'Missing caller message uses localized default');
            if ($error->notify) { like($html, qr/Site &lt;img/, 'Notified project name escaped') }
            is(scalar(() = $html =~ /href="\/contact\/form"/g), $contact ? 1 : 0, 'Contact condition unchanged');
            unlike($html, qr/<img\b/, 'Default presentation translations remain plain text');
        }
        $html = render($c, '/site/error/404.mas', message => $caller_message);
        like($html, qr/\Q$caller_message\E/, 'Standalone 404 retains caller HTML');
        unlike($html, qr/<img\b/, 'Standalone 404 title escaped');
        $html = render($c, '/site/error/permission_denied.mas');
        like($html, qr/\Q@{[encode_entities($c->i18n->p('common.error.access_denied.title', $source{'common.error.access_denied.title'}))]}\E/, 'Permission title localized');
        unlike($html, qr/<img\b/, 'Permission message escaped');
        $html = render($c, '/site/error/dhandler');
        like($html, qr/sgn-feedback\@sgn\.cornell\.edu/, 'Legacy fallback contact remains canonical');
        unlike($html, qr/<img\b/, 'Fallback handler translations escaped');
        for my $referer (undef, 'https://external.invalid/source', 'http://fixture.invalid/internal') {
            my $c404 = Local::CommonErrors::Captured404->new(translator($locale), referer => $referer, debug => 1);
            $c404->throw_404($caller_message);
            my $args = $c404->{throw};
            is($args->{http_status}, 404, '404 status retained');
            is($args->{notify}, 0, '404 notification suppression retained');
            my $internal = defined($referer) && $referer =~ /^http:\/\/fixture\.invalid/;
            is($args->{is_server_error}, $internal ? 1 : 0, 'Original referrer server condition retained');
            is($args->{is_client_error}, $internal ? 0 : 1, 'Original referrer client condition retained');
            my $diagnostic = $internal ? "404 error seems to be our fault, referrer is '$referer'" : "404 is probably not our fault.  Referrer is '".($referer || '')."'";
            is($args->{developer_message}, $diagnostic, 'Original English diagnostics retained');
            like($args->{public_message}, qr/\Q$caller_message.\E/, '404 caller HTML preserved through placeholder');
            unlike($args->{public_message}, qr/<img\b/, '404 owned text escaped independently of caller markup');
            is(scalar(() = $args->{public_message} =~ /If you reached this page/g), $internal ? 0 : 1, 'External-link notice condition retained');
            is($c404->{logs}[0], "throwing 404 error ('$caller_message.')", 'Debug input diagnostic unchanged');
            is($c404->{logs}[1], $diagnostic, 'Debug policy unchanged');
        }
        my $default = Local::CommonErrors::Captured404->new(translator($locale));
        $default->throw_404;
        like($default->{throw}{public_message}, qr/Resource not found\./, 'Default 404 keeps individually translated source');
        for my $failure (0, 1) {
            my $response = context($locale, fail_view => $failure);
            my @errors = (SGN::Exception->new(is_client_error => 1, http_status => 404), SGN::Exception->new(http_status => 503));
            $response->_set_exception_response(@errors);
            is($response->res->status, 503, 'Worst original status retained even when both renders fail');
            is($response->stash->{show_dev_message} ? 1 : 0, 0, 'Production diagnostics remain disabled');
            is_deeply($response->{forwards}, ['/insert_collected_html'], 'Original collected-HTML callback retained');
            if ($failure) {
                is_deeply($response->{renders}, ['/site/error/exception.mas', '/site/error/500.mas'], 'Original fallback order retained');
                is($response->res->content_type, 'text/plain', 'Severe fallback remains plain text');
                my $link = '<a href="/contact/form">' . $response->i18n->p('common.error.site_maintainers', $source{'common.error.site_maintainers'}) . '</a>';
                like($response->res->body, qr/\Q$link\E/, 'Fixed text/plain contact destination and localized label retained');
            } else { is($response->res->content_type, 'text/html', 'Normal response remains HTML') }
        }
    };
}
subtest 'missing catalogs keep original English' => sub {
    my $c = context('zz');
    my $e = SGN::Exception->new(is_client_error => 1, notify => 0);
    my $html = render($c, '/site/error/exception.mas', exception => $e);
    like($html, qr/>\s*Error\s*<\/h1>/, 'Unknown locale default title is English');
    like($html, qr/Our apologies, there was an error processing your request\./, 'Missing record English fallback');

};
subtest 'failed optional translator cannot prevent the fatal English response' => sub {
    my $c = Local::CommonErrors::BrokenCatalog->new(undef, fail_view => 1);
    my $error = SGN::Exception->new(http_status => 503);
    ok($c->_set_exception_response($error), 'Last-resort response returns even when the catalog getter throws');
    is($c->res->content_type, 'text/plain', 'Fatal response stays plain text');
    is($c->res->status, 503, 'Original highest status retained');
    is($c->res->body, q{Our apologies, a severe error has occurred. Please contact <a href="/contact/form">this site's maintainers</a> and report this error.}, 'Complete original English fatal text preserved');
};
subtest 'notification and developer policy remains source-owned' => sub {
    for my $production (0, 1) {
        for my $debug (0, 1) {
            my $c = context('ar', config => {production_server => $production}, debug => $debug);
            my $quiet = SGN::Exception->new(is_client_error => 1, notify => 0);
            my $notified = SGN::Exception->new(notify => 1);
            $c->{errors} = [$quiet, $notified];
            $c->finalize_error;
            is($c->res->status, 500, 'Finalizer retains worst status');
            is($c->stash->{show_dev_message} ? 1 : 0, $production ? 0 : 1, 'Developer presentation follows original production switch');
            is_deeply($c->stash->{email_errors}, $production ? [$notified] : undef, 'Only original notification candidates captured in production');
            is($c->{original_finalizer_calls} || 0, $debug && !$production ? 1 : 0, 'Native debug finalizer conditions unchanged');
            is_deeply($c->error, [], 'Original error clearing retained');
        }
    }
};
done_testing;
