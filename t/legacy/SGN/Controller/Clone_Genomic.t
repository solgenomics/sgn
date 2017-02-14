use Modern::Perl;
use Data::Dumper;
use File::Temp;

use Test::More tests => 2;

use Path::Class;

use CXGN::Genomic::Clone;
use CXGN::PotatoGenome::FileRepository;
use CXGN::Publish;

use_ok('SGN::Controller::Clone::Genomic');

my $tempdir  = File::Temp->newdir;
my $tempfile = File::Temp->new;
file($tempfile->filename)->openw->print(">RH123D21\nACTGACTGACTAGATGATCATCGATCGAGAGCG\n");

my $repos = CXGN::PotatoGenome::FileRepository->new( "$tempdir" );

my $ctl = SGN::Controller::Clone::Genomic->new;
my $clone = CXGN::Genomic::Clone->retrieve_from_clone_name( 'RH123D21' );

SKIP: {
    my $test_vf;
    eval {
        $test_vf = $repos->get_vf( class => 'SingleCloneSequence',
                        sequence_name => $clone->latest_sequence_name,
                        format => 'fasta',
                        project => $clone->seqprops->{project_country} );
    };
    skip 'could not retrieve clone, cannot test _potato_seq_files', 1 unless $test_vf;

    $repos->publish( $test_vf->publish_new_version( $tempfile->filename ) );

    skip 'could not retrieve clone, cannot test _potato_seq_files', 1 unless $clone;

    my %files = $ctl->_potato_seq_files( undef, $clone, $tempdir );
    ok( -f $files{seq}, 'got a potato seq file' )
    or diag Dumper { files =>  \%files, find => scalar(`find $tempdir`) };
}

