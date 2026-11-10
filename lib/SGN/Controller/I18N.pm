package SGN::Controller::I18N;
use Moose;
use JSON;
use File::Slurp qw(read_file);
use URI;
use URI::Escape qw(uri_unescape);
BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

SGN::Controller::I18N - browser runtime and language selection

=head1 DESCRIPTION

These actions answer only when C<i18n_enabled> is set; otherwise they give the
standard "not found" page, as if they did not exist. The page header then
loads F</i18n/runtime.js> and F</i18n/bootstrap.js>, and the language selector
posts to F</i18n/language>. Catalog text reaches the browser only as JSON data,
never as code.

=head1 ACTIONS

=head2 runtime

GET F</i18n/runtime.js>: the browser translator, F<static/js/sgn-i18n.js>.

=cut

sub runtime :Path('/i18n/runtime.js') Args(0) {
    my ($self, $c) = @_;
    $c->throw_404 unless $c->config->{i18n_enabled};
    $c->res->content_type('application/javascript; charset=UTF-8');
    $c->res->headers->header('X-Content-Type-Options' => 'nosniff');
    $c->res->headers->header('Cache-Control' => 'no-cache');
    $c->res->body(scalar read_file($c->path_to('static', 'js', 'sgn-i18n.js'), binmode => ':raw'));
}

=head2 bootstrap

GET F</i18n/bootstrap.js?lang=...&workflow=...>: the messages of the request
language for the browser (the C<common> section plus the page's section).

=cut

sub bootstrap :Path('/i18n/bootstrap.js') Args(0) {
    my ($self, $c) = @_;
    $c->throw_404 unless $c->config->{i18n_enabled};
    # Catalyst encodes response text. ASCII JSON preserves Unicode as JSON
    # escapes and prevents applying UTF-8 a second time to response bytes.
    my $json = JSON->new->canonical->ascii->encode($c->i18n->browser_catalog($c->req->param('workflow')));
    $c->res->content_type('application/javascript; charset=UTF-8');
    $c->res->headers->header('Cache-Control' => 'private, no-store');
    $c->res->headers->header('X-Content-Type-Options' => 'nosniff');
    $c->res->body('window.SGN = window.SGN || {}; if (typeof window.SGN.I18N === "function") window.SGN.i18n = new window.SGN.I18N(' . $json . ");\n");
}

=head2 language

POST F</i18n/language> with C<locale> and C<return_to>: save the chosen
language in the C<sgn_locale> cookie and go back to the local page. Login is
not changed. Unknown languages and external return addresses are rejected.

=cut

sub language :Path('/i18n/language') Args(0) {
    my ($self, $c) = @_;
    if (!$c->config->{i18n_enabled} || $c->req->method ne 'POST') {
        $c->res->status(405);
        $c->res->headers->header('Allow' => 'POST');
        $c->res->body('Language selection requires an enabled feature and POST.');
        return;
    }
    my $locale = $c->req->param('locale') || '';
    my %allowed = map { $_->{locale} => 1 } $c->i18n_locale_choices;
    if (!$allowed{$locale}) {
        $c->res->status(400);
        $c->res->body('Unsupported language.');
        return;
    }
    $c->res->cookies->{sgn_locale} = {
        value => $locale, path => '/', httponly => 1, samesite => 'Lax',
        secure => ($c->req->uri->scheme eq 'https' ? 1 : 0),
        expires => '+1y',
    };
    my $path = _return_path($c->req->param('return_to'));
    $c->res->redirect($path, 303);
}

# Return a safe local path for the redirect after a language change. External
# or ambiguous addresses become "/". An old "lang" query parameter is removed,
# because it would override the newly saved cookie.
sub _return_path {
    my ($value) = @_;
    return '/' if !defined($value) || ref($value) || length($value) > 8192;
    return '/' unless $value =~ m{\A/(?!/)};
    return '/' if $value =~ /[\x00-\x20\x7f\\]/ || $value =~ /%(?:0[ad]|5c)/i;
    my $uri = URI->new($value);
    return '/' if defined($uri->scheme) || defined($uri->authority);
    my $path = $uri->path;
    for (1..2) {
        $path = uri_unescape($path);
        return '/' if $path =~ m{\A//} || $path =~ /[\x00-\x20\x7f\\]/;
    }
    if (defined(my $query = $uri->query)) {
        my @parts = grep { uri_unescape((split /=/, $_, 2)[0]) ne 'lang' } split /[&;]/, $query;
        $uri->query(@parts ? join('&', @parts) : undef);
    }
    return $uri->as_string;
}

1;
