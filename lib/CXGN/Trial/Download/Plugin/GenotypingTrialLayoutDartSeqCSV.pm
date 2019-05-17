
package CXGN::Trial::Download::Plugin::GenotypingTrialLayoutDartSeqCSV;

=head1 NAME

CXGN::Trial::Download::Plugin::GenotypingTrialLayoutDartSeqCSV

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading a genotyping plate's layout (as used from CXGN::Trial::Download->trial_download):

my $plugin = "GenotypingTrialLayoutDartSeqCSV";

my $download = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_id => $c->stash->{trial_id},
    filename => $tempfile,
    format => $plugin,
});
my $error = $download->download();
my $file_name = $trial_id . "_" . "$what" . ".$format";
$c->res->content_type('Application/'.$format);
$c->res->header('Content-Disposition', qq[attachment; filename="$file_name"]);
my $output = read_file($tempfile);
$c->res->body($output);


=head1 AUTHORS

=cut

use Moose::Role;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use CXGN::Trial;
use CXGN::Trial::TrialLayout;
use Text::CSV;

sub verify { 
    return 1;
} 

sub download { 
    my $self = shift;

    print STDERR "DATALEVEL ".$self->data_level."\n";

    open(my $F, ">:encoding(utf8)", $self->filename()) || die "Can't open file ".$self->filename();

    my $csv = Text::CSV->new({eol => $/});

    my @header = ('PlateID', 'Row', 'Column', 'Organism', 'Species', 'Genotype', 'Tissue', 'Comments');
    $csv->print($F, \@header);

    my $trial = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $self->trial_id });
    my $trial_name = $trial->get_name();
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $self->bcs_schema, trial_id => $self->trial_id,, experiment_type => 'genotyping_layout'});
    my $design = $trial_layout->get_design();
    #print STDERR Dumper $design;

    my $q = "SELECT common_name FROM organism WHERE species = ?;";
    my $h = $self->bcs_schema->storage->dbh()->prepare($q);

    my @output_array;
    foreach my $key (sort keys %$design){
        my $val = $design->{$key};
        my $notes = $val->{notes} || 'NA';
        my $acquisition_date = $val->{acquisition_date} || 'NA';
        my $concentration = $val->{concentration} || 'NA';
        my $volume = $val->{volume} || 'NA';
        my $dna_person = $val->{dna_person} || 'NA';
        my $extraction = $val->{extraction} || 'NA';
        my $comments = 'Notes: '.$notes.' AcquisitionDate: '.$acquisition_date.' Concentration: '.$concentration.' Volume: '.$volume.' Person: '.$dna_person.' Extraction: '.$extraction;
        my $sample_name = $val->{plot_name}."|||".$val->{accession_name};
        my $letter = substr $val->{plot_number}, 0 , 1;

        $h->execute($val->{species});
        my ($common_name) = $h->fetchrow_array();

        if (!$val->{is_blank}) {
            push @output_array, [
                $trial_name,
                $letter,
                $val->{col_number},
                $common_name,
                $val->{species},
                $sample_name,
                $val->{tissue_type},
                $comments
            ];
        }
    }
    foreach my $l (@output_array){
        $csv->print($F, $l);
    }
    close($F);
}

1;
