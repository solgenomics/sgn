
package CXGN::Trial::Download::Plugin::TrialLayoutExcel;

=head1 NAME

CXGN::Trial::Download::Plugin::TrialLayoutCSV

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download

------------------------------------------------------------------

For downloading a trial's layout (as used from CXGN::Trial::Download->trial_download):

A trial's layout can optionally include treatment and phenotype summary
information, mapping to treatment_project_ids and trait_list, selected_trait_names.
These keys can be ignored if you don't need them in the layout.

As a XLS:
my $plugin = "TrialLayoutExcel";

As a CSV:
my $plugin = "TrialLayoutCSV";

my $download = CXGN::Trial::Download->new({
    bcs_schema => $schema,
    trial_id => $c->stash->{trial_id},
    trait_list => \@trait_list,
    filename => $tempfile,
    format => $plugin,
    data_level => $data_level,
    treatment_project_ids => \@treatment_project_ids,
    selected_columns => $selected_cols,
    selected_trait_names => \@selected_trait_names,
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
use CXGN::Trial::TrialLayout;
use CXGN::Trial;
use CXGN::Trial::TrialLayoutDownload;

sub verify { 
    return 1;
}

sub download { 
    my $self = shift;

    $self->trial_download_log($self->trial_id, "trial layout excel");

    print STDERR "DATALEVEL ".$self->data_level."\n";
    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();

    my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
        schema => $self->bcs_schema,
        trial_id => $self->trial_id,
        data_level => $self->data_level,
        treatment_project_ids => $self->treatment_project_ids,
        selected_columns => $self->selected_columns,
        selected_trait_ids => $self->trait_list,
        selected_trait_names => $self->selected_trait_names
    });
    my $output = $trial_layout_download->get_layout_output();
    if ($output->{error_messages}){
        return $output;
    }
    my @output_array = @{$output->{output}};
    my $row_num = 0;
    foreach my $l (@output_array){
        my $col_num = 0;
        foreach my $c (@$l){
            $ws->write($row_num, $col_num, $c);
            $col_num++;
        }
        $row_num++;
    }

}

1;
