
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

sub verify { 
    return 1;
} 

sub download { 
    my $self = shift;

    print STDERR "DATALEVEL ".$self->data_level."\n";

    open(my $F, ">", $self->filename()) || die "Can't open file ".$self->filename();

    my @header = ('Plate ID', 'Row', 'Column', 'Organism', 'Species', 'Genotype', 'Tissue', 'Comments');
    print $F '"';
    print $F join '","', @header;
    print $F '"';
    print $F "\n";

    my $trial = CXGN::Trial->new( { bcs_schema => $self->bcs_schema, trial_id => $self->trial_id });
    my $trial_name = $trial->get_name();
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $self->bcs_schema, trial_id => $self->trial_id,, experiment_type => 'genotyping_layout'});
    my $design = $trial_layout->get_design();
    #print STDERR Dumper $design;
    my @output_array;
    foreach my $key (sort keys %$design){
        my $val = $design->{$key};
        my $comments = 'Notes: '.$val->{notes}.' AcquisitionDate: '.$val->{acquisition_date}.' Concentration: '.$val->{concentration}.' Volume: '.$val->{volume}.' Person: '.$val->{dna_person}.' Extraction: '.$val->{extraction};
        my $sample_name = $val->{plot_name}."|||".$val->{accession_name};
        push @output_array, [
            $trial_name,
            $val->{row_number},
            $val->{col_number},
            'Cassava',
            $val->{species},
            $sample_name,
            $val->{tissue_type},
            $comments
        ];
    }
    foreach my $l (@output_array){
        print $F '"';
        print $F join '","', @$l;
        print $F '"';
        print $F "\n";
    }
    close($F);
}

1;
