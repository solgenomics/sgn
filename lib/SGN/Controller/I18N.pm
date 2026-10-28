package SGN::Controller::I18N;
use Moose;
use JSON;
use File::Slurp qw(read_file);
BEGIN { extends 'Catalyst::Controller' }

=head1 NAME

SGN::Controller::I18N - safe browser bootstrap and language preference

=head1 DESCRIPTION

Catalog values are JSON data. Bootstrap resources are external, so user text
cannot terminate an inline script element. The runtime contains trusted code
only; language packs cannot replace it. Preferences preserve existing login.

=cut

sub runtime :Path('/i18n/runtime.js') Args(0) {
    my ($self, $c) = @_;
    my @paths = (
        $c->path_to('static', 'js', 'sgn-i18n.js'),
    );
    $c->res->content_type('application/javascript; charset=UTF-8');
    $c->res->headers->header('X-Content-Type-Options' => 'nosniff');
    $c->res->headers->header('Cache-Control' => 'no-cache');
    $c->res->body(join("\n", map { scalar read_file($_, binmode => ':raw') } @paths));
}

sub bootstrap :Path('/i18n/bootstrap.js') Args(0) {
    my ($self, $c) = @_;
    # Catalyst encodes response text. ASCII JSON preserves Unicode as JSON
    # escapes and prevents applying UTF-8 a second time to response bytes.
    my $json = JSON->new->canonical->ascii->encode($c->i18n->browser_catalog($c->req->param('workflow')));
    $c->res->content_type('application/javascript; charset=UTF-8');
    $c->res->headers->header('Cache-Control' => 'private, no-store');
    $c->res->headers->header('X-Content-Type-Options' => 'nosniff');
    $c->res->body('window.SGN = window.SGN || {}; if (typeof window.SGN.I18N === "function") window.SGN.i18n = new window.SGN.I18N(' . $json . ");\n");
}

sub language :Path('/i18n/language') Args(0) {
    my ($self, $c) = @_;
    if (!$c->config->{i18n_enabled} || $c->req->method ne 'POST') {
        $c->res->status(405);
        $c->res->headers->header('Allow' => 'POST');
        $c->res->body('Language selection requires an enabled feature and POST.');
        return;
    }
    my $locale = $c->req->param('locale') || '';
    my %allowed = map { $_ => 1 } $c->i18n_locales;
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
    my $path = $c->req->param('return_to') || '/';
    $path = '/' unless $path =~ m{^/(?!/)[A-Za-z0-9_./-]*$};
    $c->res->redirect($path, 303);
}

1;
