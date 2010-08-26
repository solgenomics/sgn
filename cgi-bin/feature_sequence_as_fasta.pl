use strict;
use warnings;
use CGI qw();
use CXGN::DB::DBICFactory;
use Data::Dumper;
use Bio::SeqIO;

use CatalystX::GlobalContext qw( $c );
my $q = new CGI;
my %args = (
    schema => CXGN::DB::DBICFactory->open_schema('Bio::Chado::Schema')
);
my $bcs   = $args{schema};
my $param = $q->Vars;
print $q->header(
    -type => 'text/txt',
    -expires => '+1d',
);

my $feature_id = $param->{feature_id};
$c->throw( message => "Must provide a feature id") unless $feature_id;
my ($start,$end) = ($param->{start}, $param->{end});
if (defined $start or defined $end) {
    $c->throw( message => "start must be greater than 0" ) unless $start > 0;
    $c->throw( message => "end must be greater than start" ) unless $end > $start;
}

my $matching_features = $bcs->resultset('Sequence::Feature')
                            ->search({ feature_id => $feature_id });
my $count = $matching_features->count;
$c->throw( message => "feature with feature id='$feature_id' not found") if $count < 1;

my $feature   = $matching_features->next;
my $sequence  = Bio::PrimarySeq->new(
                -id  => $feature_id,
                -seq => $feature->residues
                );
if ($start and $end) {
    $sequence = Bio::PrimarySeq->new( 
                    -id  => $feature->name . ":$start..$end",
                    -seq => $sequence->subseq($start,$end),
                );
}
my $fh = Bio::SeqIO->new(
        -format => 'fasta',
        -fh     => \*STDOUT)
        ->write_seq( $sequence );
print $_ while <$fh>;
