use strict;
use CGI qw();
use CXGN::DB::DBICFactory;
use Data::Dumper;
use Bio::SeqIO;

our $c;
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

$c->throw( message => "Must provide a feature id") unless $param->{id};
my $feature_id = $param->{id};

my $matching_features = $bcs->resultset('Sequence::Feature')
                            ->search({ feature_id => $feature_id });
my $count = $matching_features->count;
$c->throw( message => "feature with feature id='$feature_id' not found") if $count < 1;

my $feature   = $matching_features->next;

my $fh = Bio::SeqIO->new(
        -format => 'fasta',
        -fh     => \*STDOUT)
        ->write_seq(
            Bio::PrimarySeq->new(
                -id  => $feature_id,
                -seq => $feature->residues )
        );
print $_ while <$fh>;
