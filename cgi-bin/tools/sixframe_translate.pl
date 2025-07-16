use CatalystX::GlobalContext qw( $c );
# instead of linking to this, consider just embedding the translations
# directly into the relevant detail page

use strict;
use warnings;

use CGI;
use Bio::PrimarySeq;

my $cgi = CGI->new;
my $seq = get_legacy_est( $cgi ) || get_legacy_unigene( $cgi ) || get_direct_seq( $cgi )
    or $c->throw( message => 'No sequence found.', is_error => 0 );

$c->forward_to_mason_view( '/tools/sixframe_translate_standalone.mas',
                           seq => $seq,
                           blast_url => '/tools/blast'
                         );


# ========= helper functions =======

sub get_legacy_est {
    my ($cgi) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    my $est_id = $cgi->param('est_id')
        or return;

    my $est = $c->dbic_schema('SGN::Schema', undef, $sp_person_id)
                ->resultset('Est')
                ->find( $est_id )
        or return;

    return Bio::PrimarySeq->new( -id   => "SGN-E".($est_id+0),
                                 -seq  => $est->hqi_seq,
                               );
}

sub get_legacy_unigene {
    my ($cgi) = @_;

    my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;

    my $unigene_id = $cgi->param('unigene_id')
        or return;

    my $unigene = $c->dbic_schema('SGN::Schema', undef, $sp_person_id)
                    ->resultset('Unigene')
                    ->find( $unigene_id )
        or return;

    return Bio::PrimarySeq->new( -id   => 'SGN-U'.( $unigene_id+0 ),
                                 -seq  => $unigene->seq,
                               );
}

sub get_direct_seq {
    my ($cgi) = @_;

    my $seq = $cgi->param('seq')
        or return;

    my ( $seqid, $sequence ) = split '#', $seq;
    return Bio::PrimarySeq->new( -id => $seqid, -seq => $seq );

}

