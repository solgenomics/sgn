package CXGN::Trial::Download::Plugin::SoilDataXLS;

=head1 NAME

CXGN::Trial::Download::Plugin::SoilDataXLS

=head1 SYNOPSIS

This plugin module is loaded from CXGN::Trial::Download


=head1 AUTHORS

=cut

use Moose::Role;
use Data::Dumper;
use Spreadsheet::WriteExcel;
use CXGN::BreedersToolbox::SoilData;

sub verify {
    return 1;
}

sub download {
    my $self = shift;
    my $schema = $self->bcs_schema,
    my $trial_id = $self->trial_id;
    my $prop_id = $self->prop_id;
#    print STDERR "PROP ID 2 =".Dumper($prop_id)."\n";
    my $ss = Spreadsheet::WriteExcel->new($self->filename());
    my $ws = $ss->add_worksheet();

    my @header = ('Data Type', 'Data Value' );

    my $col_count = 0;
    foreach (@header){
        $ws->write(0, $col_count, $_);
        $col_count++;
    }

    my $trial = $schema->resultset("Project::Project")->find( { project_id => $trial_id });
    my $trial_name = $trial->name();

    my @download_info;
    push @download_info, ['Trial Name', $trial_name];

    my $soil_data_obj = CXGN::BreedersToolbox::SoilData->new({ bcs_schema => $schema, prop_id => $prop_id, parent_id => $trial_id });
    my $soil_data = $soil_data_obj->get_soil_data();
    push @download_info, ['Soil Data Description', $soil_data->[0]];
    push @download_info, ['Soil Data Year', $soil_data->[1]];
    push @download_info, ['Soil Data GPS', $soil_data->[2]];
    push @download_info, ['Type of Sampling', $soil_data->[3]];

    my $data_type_order = $soil_data->[4];
    my @types = @$data_type_order;
    my $soil_data_details = $soil_data->[5];
    foreach my $type (@types) {
        push @download_info, [$type, $soil_data_details->{$type}];
    }

    my $row_count = 1;
    for my $k (0 .. $#download_info) {
        for my $l (0 .. $#header) {
            $ws->write($row_count, $l, $download_info[$k][$l]);
        }
        $row_count++;
    }

}



1;
