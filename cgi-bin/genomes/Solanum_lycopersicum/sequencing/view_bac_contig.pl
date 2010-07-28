use strict;
use warnings;

use CGI ();
use Data::Dumper;

use CXGN::BioTools::AGP qw/ agp_contigs agp_contig_seq agp_parse /;
use CXGN::TomatoGenome::BACPublish qw/ agp_file /;
use CXGN::Publish;

my $cgi = CGI->new;
my $publisher = CXGN::Publish->new;
my $bcs = $c->dbic_schema('Bio::Chado::Schema');

if( my $contig_name = $cgi->param('contig') ) {
    $contig_name =~ s/[^\w\.]//g; #< sanitize the contig name

    my $p = CXGN::Tools::Identifiers::parse_identifier($contig_name,'tomato_bac_contig')
        or $c->throw( message => "Invalid contig identifier $contig_name", is_error => 0 );

    my $agp_file_unversioned = agp_file( $p->{chr}, 'unpublished' )
        or $c->throw( message => 'No AGP file found for chromosome '.$p->{chr} );

    my $agp_publishing_record = $publisher->publishing_history( $agp_file_unversioned );
    #$c->throw( message => 'break', developer_message => '<pre>'.Dumper($agp_publishing_record).'</pre>' );

    # hash of file version => publishing record (which is { version => $num, fullpath => path to file })
    my %agp_versions = map { $_->{version} => $_ }
        ( $agp_publishing_record, @{ $agp_publishing_record->{ancestors} || []} );

    my $agp_file = $agp_versions{ $p->{ver} }->{fullpath}
        or $c->throw( message => "No AGP file found for chromosome $p->{chr} version $p->{ver}",
                      developer_message => join '', (
                          "<pre>",
                          Dumper({ agp_versions => \%agp_versions,
                                   agp_publishing_record => $agp_publishing_record,
                                   agp_file_unversioned => $agp_file_unversioned
                                  }),
                          '</pre>',
                         ),
                     );

    my @contigs = agp_contigs( agp_parse( $agp_file ) );
    my $contig = $contigs[ $p->{ctg_num} - 1 ]
        or $c->throw( message => "No contig $p->{ctg_num} found in AGP for chromosome $p->{chr}.$p->{ver}",
                      developer_message => join '', (
                          "<pre>",
                          Dumper({ contigs => \@contigs,
                                   contig_count => scalar(@contigs),
                                   agp_file => $agp_file,
                                }),
                          '</pre>',
                         ),
                     );

    $c->forward_to_mason_view(
        '/genomes/Solanum_lycopersicum/sequencing/view_contig/view.mas',
        contig      => $contig,
        contig_name => $contig_name,
        seq_source => sub {
            my $seq_name = shift;
            my $feat = $bcs->resultset('Sequence::Feature')->search({name => $seq_name},{rows => 1})->single
                or $c->throw( message => "Sequence $seq_name not found" );
            #die Dumper({ name => $feat->id, residues => $feat->seq });
            return $feat->residues; #< feature acts as a Bio::PrimarySeqI
        },
       );
} else {
    $c->forward_to_mason_view('/genomes/Solanum_lycopersicum/sequencing/view_contig/input.mas');
}
