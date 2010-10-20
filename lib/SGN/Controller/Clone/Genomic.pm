=head1 NAME

SGN::Controller::Clone::Genomic - Catalyst controller for dealing with
genomic clone data

=cut

package SGN::Controller::Clone::Genomic;
use namespace::autoclean;
use Moose;
use Carp;

use Memoize;
use File::Basename;

use CXGN::DB::DBICFactory;
use CXGN::Genomic::Clone;

use CXGN::PotatoGenome::Config;
use CXGN::PotatoGenome::FileRepository;
use CXGN::TomatoGenome::Config;

BEGIN { extends 'SGN::Controller::Clone' }

with 'Catalyst::Component::ApplicationAttribute';

=head1 ACTIONS

=head2 clone_annot_download

Public Path: /genomic/clone/<clone_id>/annotation/download?set=<set_name>&format=<format>

Download an annotation set for a particular clone.

=cut

sub clone_annot_download :Chained('get_clone') :PathPart('annotation/download') :Args(0) {
    my ( $self, $c, $annot ) = @_;

    my ( $set, $format ) = @{ $c->req->query_parameters }{'set','format'};
    $set =~ s![\\/]!!g;
    $format =~ s/\W//g;

    my $clone = $c->stash->{clone};

    my %files =
        $self->_is_tomato($clone) ? CXGN::TomatoGenome::BACPublish::sequencing_files( $clone, $c->config->{'ftpsite_root'} ) :
        $self->_is_potato($clone) ? $self->_potato_seq_files( $c, $clone )                                                   :
	                            $c->throw_404('No annotation sets found for that clone.');

    %files or $c->throw_404('No annotation sets found for that clone.');

    if( my $file = $files{$set eq 'all' ? $format : $set.'_'.$format} ) {
        $c->stash->{download_filename} = $file;
        $c->forward('Controller::Download','download');
    } else {
        $c->throw_404('Annotation set not found.');
    }
}

=head2 get_clone

Public path: /genomic/clone/<clone_id>

Chaining base for fetching a CXGN::Genomic::Clone, stashes the clone
object in $c->stash->{clone}

=cut

sub get_clone :Chained('/') PathPart('genomic/clone') :CaptureArgs(1) {
    my ( $self, $c, $clone_id ) = @_;

    $c->stash->{clone} =
        CXGN::Genomic::Clone->retrieve( $clone_id )
              or $c->throw_404('Clone not found.');

}

# find the chado organism for a clone
sub _clone_organism {
    my ( $self, $clone ) = @_;
    $self->_app->dbic_schema('Bio::Chado::Schema','sgn_chado')->resultset('Organism::Organism')->find( $clone->library_object->organism_id );
}

sub _is_tomato {
    my ( $self, $clone ) = @_;
    return lc $self->_clone_organism($clone)->species eq 'solanum lycopersicum';
}
sub _is_potato {
    my ( $self, $clone ) = @_;
    return lc $self->_clone_organism($clone)->species eq 'solanum tuberosum';
}

sub _clone_seq_project_name {
    my ( $self, $clone ) = @_;
    if( $self->_is_tomato( $clone ) ) {
        my $chr = $clone->chromosome_num;
        return "Chromosome $chr" if defined $chr;
        return 'none';
    } elsif( $self->_is_potato( $clone ) ) {
	return $clone->seqprops->{project_country} || 'unknown';
    } else {
	return 'none';
    }
}

sub _potato_seq_files {
    my ( $self, $c, $clone, $repos_path ) = @_;

    return unless $clone->latest_sequence_name;
    return unless $clone->seqprops->{project_country};

    $repos_path ||=  CXGN::PotatoGenome::Config->load_locked->{repository_path};

    return unless -d $repos_path;

    my $repos = CXGN::PotatoGenome::FileRepository->new( $repos_path );

    my $seq = $repos->get_file( class         => 'SingleCloneSequence',
				sequence_name => $clone->latest_sequence_name,
				project       => $clone->seqprops->{project_country},
				format => 'fasta',
			      );
    #warn $clone->clone_name." -> ".$seq;
    return ( seq => $seq );
}

  #make an ftp site link
sub _ftp_seq_repos_link {
    my ( $self, $c, $clone ) = @_;

    my $ftp_base = $c->config->{ftpsite_url};

    if( $self->_is_tomato( $clone ) ) {
	my $chr = $clone->chromosome_num;
	my $chrnum = $chr;
	$chrnum = 0 if $chr eq 'unmapped';
	my $ftp_subdir =   $chr ? sprintf("chr%02d/",$chrnum) : '';
	my $project_name = $chr ? $chr eq 'unmapped' ? 'Unmapped Clones '
	    : "Chromosome $chrnum "
		: '';
	my $bac_dir = CXGN::TomatoGenome::Config->load_locked->{'bac_publish_subdir'};
	return qq|<a href="$ftp_base/$bac_dir/$ftp_subdir">${project_name}Sequencing repository (FTP)</a>|;
    }
    elsif( $self->_is_potato( $clone ) ) {
	my $country = $clone->seqprops->{project_country} || '';
	my $bac_dir = CXGN::PotatoGenome::Config->load_locked->{'bac_publish_subdir'};
	my $subdir =  $country ? "$country/" : '';
	return qq|<a href="$ftp_base/$bac_dir/$subdir">$country Sequencing repository (FTP)</a>|;
    }

    return '<span class="ghosted">not available</span>';
}


__PACKAGE__->meta->make_immutable;
1;
