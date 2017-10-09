
package CXGN::Trial::Download::Plugin::TrialLayoutExcel;

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
