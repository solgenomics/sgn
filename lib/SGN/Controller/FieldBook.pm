
package SGN::Controller::FieldBook;

use Moose;
use URI::FromHash 'uri';
use Spreadsheet::WriteExcel;
use File::Slurp qw | read_file |;
use File::Temp;
use Data::Dumper;
use CXGN::Trial::TrialLayout;

BEGIN { extends 'Catalyst::Controller'; }

sub field_book :Path("/fieldbook") Args(0) { 
    my ($self , $c) = @_;
    if (!$c->user()) { 
	# redirect to login page
	$c->res->redirect( uri( path => '/solpeople/login.pl', query => { goto_url => $c->req->uri->path_query } ) ); 
	return;
    }
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    # get projects
    #
    my @rows = $schema->resultset('Project::Project')->all();
    my @projects = ();
    foreach my $row (@rows) { 
	push @projects, [ $row->project_id, $row->name, $row->description ];
    }
    $c->stash->{projects} = \@projects;
    # get roles
    my @roles = $c->user->roles();
    $c->stash->{roles}=\@roles;
    $c->stash->{template} = '/fieldbook/home.mas';
}

sub trial_field_book_download : Path('/fieldbook/trial_download/') Args(1) { 
    my $self  =shift;
    my $c = shift;
    my $trial_id = shift;
    die "No trial id supplied" if !$trial_id;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $trial = $schema->resultset('Project::Project')->find({project_id => $trial_id});
    die "Trial does not exist with id $trial_id" if !$trial;
    my $dir = $c->tempfiles_subdir('/other');
    my $tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'other/excelXXXX');
    my $wb = Spreadsheet::WriteExcel->new($tempfile);
    die "Could not create excel file " if !$wb;
    my $ws = $wb->add_worksheet();
    my $trial_layout = CXGN::Trial::TrialLayout->new({schema => $schema, trial_id => $trial_id} );
    my $trial_name =  $trial_layout->get_trial_name();

    $ws->write(0, 0, 'plot_id');
    $ws->write(0, 1, 'range');
    $ws->write(0, 2, 'plot');
    $ws->write(0, 3, 'rep');
    $ws->write(0, 4, 'accession');
    $ws->write(0, 5, 'is_a_control');

    my %design = %{$trial_layout->get_design()};
    my $row_num = 1;
    foreach my $key (sort { $a <=> $b} keys %design) {
      my %design_info = %{$design{$key}};
      $ws->write($row_num,0,$design_info{'plot_name'});
      $ws->write($row_num,1,$design_info{'block_number'});
      $ws->write($row_num,2,$design_info{'plot_number'});
      $ws->write($row_num,3,$design_info{'rep_number'});
      $ws->write($row_num,4,$design_info{'accession_name'});
      $ws->write($row_num,5,$design_info{'is_a_control'});
      $row_num++;
    }
    $wb->close();
    my $contents = read_file($tempfile);
    $c->res->content_type('Application/xls');
    $c->res->header('Content-Disposition', qq[attachment; filename="fieldbook_layout_$trial_name.xls"]);
    $c->res->body($contents);
}

1;
