package SGN::Controller::Project::Secretom;
use Moose;
use namespace::autoclean;
use Carp;
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
           )->stringify
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

    $c->stash->{template} = my $comp_name = "$path.mas";

    $c->throw_404
        unless $c->view('Mason')->component_exists( $comp_name );
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

=head2 signalp_search

Conduct a search of the signalp results.

GET params:

  q - the query text search for
  file - the file basename to search in, optional

Conducts a search and displayes the results as HTML.

=cut

sub signalp_search :Path('search/signalp') {
    my ( $self, $c ) = @_;

    my $file = $c->req->param('file');  $file =~ s!\\/!!g; # no dir seps, no badness.
    $file ||= 'AtBrRiceTomPop.tab';  # use uncompressed file for speed # 'Tair10_all.tab.gz'; 
    my $abs_file = $self->static_dir->file( 'data','secretom', 'SecreTarySPTP_predictions', $file  );
print "abs_file: $abs_file \n";	
    $c->stash->{headings} = [
	"Locus name",
	"Annotation",
	"Protein length",
	"Molecular weight",
	"SignalP-nn Dscore",
	"SignalP-nn (YES if Dscore >= 0.43, NO otherwise)",
	"SignalP-nn pred sp len",
	"SignalP-hmm sp score",
	"SignalP-hmm sa score",
	"SignalP-hmm prediction (SP,SA or NS)",
	"TargetP result (C,M,S,_)",
	"SecreTary score",
	"SecreTary prediction (ST+ if score >= 0.75)"
       ];

    $c->stash->{query}    = my $q = $c->req->param('q');
    $c->stash->{csv_download} = $c->uri_for( $self->action_for('signalp_search_csv'), { q => $q, file => "$file" } );
    $c->stash->{data}     = [ $self->_search_signalp_file( $q, $abs_file ) ];
    $c->stash->{template} = '/secretom/signalp_search_result.mas';

}

=head1 signalp_search_csv

Same as signalp_search, except displays the results as CSV.

=cut

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
    $query =~ s/ ^\s+ | \s+$ //gx; # remove initial and final whitespace
#  $query =~ s/ [^\w\s] //gx; # removes characters which are neither
# word ([a-zA-Z0-9_]) or whitespace characters. But then somthing like
# AT1G37010.1 becomes AT1G370101 and we get no matches. 
    $query =~ s/\s+/'\s+'/ge;
    $query = qr|$query|;

my $fh;
#   open $fh, "gunzip -c '$file' |" or die "$! unzipping $file";
   
open ($fh, "<", $file) or carp "Failed to open file: $file for reading.\n";
    
my @results;
    while ( my $line = <$fh> ) {
      next unless lc($line) =~ $query;
      # choose the fields in the tab file to keep
      my @fields = (split /\t/, $line)[
				       0, # id
				       1, # protein length
				       4, # Molecular weight
				       5, # Annotation
				       6, # SPnn Dscore
				       7, # SPnn prediction 
				       8, # SPnn signal peptide predicted length
				       9, # SPhmm sp score
				       10, # SPhmm sa (signal anchor) score
				       11, # SPhmm prediction
				       12, # TargetP prediction (C,M,S,_)
				       13, # SecreTary score (>= 0.75 -> pass)
				       14 # SecreTary prediction (pass/fail)
				      ];
my $STpred = pop @fields;
$STpred = ($STpred eq 'pass')? 'ST+': 'ST-';
push @fields, $STpred;

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

