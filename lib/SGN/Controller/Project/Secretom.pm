package SGN::Controller::Project::Secretom;
use Moose;
use namespace::autoclean;

use MooseX::Types::Path::Class;

use JSON::Any; my $json = JSON::Any->new;

BEGIN {extends 'Catalyst::Controller'; }
with 'Catalyst::Component::ApplicationAttribute';

__PACKAGE__->config(
    namespace => 'secretom',
   );

has 'static_dir' => (
    is    => 'rw',
    isa    => 'Path::Class::Dir',
    coerce => 1,
    default => sub {
        my $self = shift;
        $self->_app->path_to(
            $self->_app->config->{root},
           );
    },
   );

=head1 NAME

SGN::Controller::Project::Secretom - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

Does nothing, just forwards to the default template
(/secretom/index.mas), see L<Catalyst::Action::RenderView>.

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    #$c->response->body('Matched SGN::Controller::Project::Secretom in Project::Secretom.');
}

=head2 default

Just forwards to the template indicated by the request path.

=cut

sub default :Path {
    my ( $self, $c, @args ) = @_;
    my $path = join '/', $self->action_namespace, @args;
    if( $path =~ s/\.pl$// ) { #< attempt to su
        $c->res->redirect( $path, 301 );
    }
    $c->stash->{template} = "$path.mas"
}

=head2 auto

Sets some config needed by the templates.

=cut

sub auto :Private {
    my ( $self, $c, @args ) = @_;

    # set the root dir for secretom static files.  used by some of the
    # templates.
    $c->stash->{static_dir} = $self->static_dir;
    $c->stash->{signalp_search_action} = $c->uri_for( $self->action_for('signalp_search') );
}

sub signalp_search :Path('search/signalp') {
    my ( $self, $c ) = @_;

    my $file = $c->req->param('file');  $file =~ s!\\/!!g; # no dir seps, no badness.
    $file ||= 'Tair9RiceBrachyITAG1.tab.gz';
    my $abs_file = $self->static_dir->file( 'data','secretom', '.new', 'SignalP_predictions', $file  );

    $c->stash->{headings} = [
	"Locus name",
	"Annotation",
	"Protein length",
	"Molecular weight",
	"SignalP-nn (Dscore)",
	"SignalP-nn (YES if Dscore >= 0.43, NO otherwise)",
	"SignalP-nn pred sp len",
	"SignalP-hmm sp score",
	"SignalP-hmm sa score",
	"SignalP-hmm prediction (SP,SA or NS)",
	"TargetP result (C,M,S,_)",
       ];

    $c->stash->{query}    = my $q = $c->req->param('q');
    $c->stash->{csv_download} = $c->uri_for( $self->action_for('signalp_search_csv'), { q => $q, file => "$file" } );
    $c->stash->{data}     = [ $self->_search_signalp_file( $q, $abs_file ) ];
    $c->stash->{template} = '/secretom/signalp_search_result.mas';

}
sub signalp_search_csv :Path('search/signalp/csv') {
    my ( $self, $c ) = @_;
    $c->forward( $self->action_for('signalp_search') );


    $c->res->content_type('text/csv');
    $c->res->headers->push_header( 'Content-disposition', 'attachment' );
    $c->res->headers->push_header( 'Content-disposition', 'filename=signalp_search.csv' );
    $c->res->body( join '', map "$_\n",
                   map { join ',', map qq|"$_"|, @$_ }
                   $c->stash->{headings},,
                   @{$c->stash->{data}}
                  );
}

sub _search_signalp_file {
    my ( $self, $query, $file ) = @_;

    # normalize and compile query
    $query = lc $query;
    $query =~ s/ ^\s+ | \s+$ | [^\w\s] //gx;;
    $query =~ s/\s+/'\s+'/ge;
    $query = qr|$query|;

    open my $fh, "gunzip -c '$file' |" or die "$! unzipping $file";
    my @results;
    while( my $line = <$fh> ) {
        next unless lc($line) =~ $query;
        my @fields = (split /\t/, $line)[0,1,4,5,6,7,8,9,10,11,12];
        push @results, \@fields;
    }

    return @results;
}


=head1 AUTHOR

Robert Buels

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

