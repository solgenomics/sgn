package SGN::Test::solGSData;


use Moose;

use lib 't/lib';
use SGN::Test::Fixture;
use CXGN::List;
use CXGN::Dataset;

has 'user_id' => (isa => 'Int',
    is => 'rw',
    required => 1
);


sub add_plots_list {
    my $self = shift;

    my $list_id = $self->create_plots_list();
    my $plots = $self->plots_list();

    return  $self->add_list_elems($list_id, $plots, 'plots');

}


sub create_list {
    my $self = shift;
    my $name = shift;
    my $desc = shift;

    my $user_id = $self->user_id();
    my $dbh = $self->get_dbh;

    my $list_id = CXGN::List::create_list($dbh, $name, $desc, $user_id );

    return $list_id;

}

sub create_plots_list {
    my $self = shift;

    my $name = '60 NaCRRI plots';
    my $desc = 'solgs plots list';

    my $list_id = $self->create_list($name, $desc);

    return $list_id;

}

sub create_trials_list {
    my $self = shift;

    my $name = '2 NaCRRI trials';
    my $desc = 'solgs nacrri list';

    my $list_id = $self->create_list($name, $desc);

    return $list_id;

}

sub create_accessions_list {
    my $self = shift;

    my $name = '34 accessions';
    my $desc = 'solgs clones list';

    my $list_id = $self->create_list($name, $desc);

    return $list_id;

}


sub add_accessions_list {
    my $self = shift;

    my $list_id = $self->create_accessions_list();
    my $accs = $self->accessions_list();
    print STDERR "\nadd accessions: @$accs\n";

    return $self->add_list_elems($list_id, $accs, 'accessions');

}

sub add_trials_list {
    my $self = shift;

    my $list_id = $self->create_trials_list();
    my $trials = $self->trials_list();
    print STDERR "\nadd strials: @$trials\n";

    return $self->add_list_elems($list_id, $trials, 'trials');

}

sub add_list_elems {
    my $self = shift;
    my $list_id = shift;
    my $elems = shift;
    my $type = shift;

    my $dbh = $self->get_dbh();

    my $list = CXGN::List->new({dbh => $dbh, list_id => $list_id});
    $list->type($type);

    print STDERR "\nadding $type...: @$elems\n";
    my $res = $list->add_bulk($elems);

    return { list_id => $list_id,
        list_name => $list->name
    };

}

sub get_dbh {
    my $self = shift;

    my $fixture = SGN::Test::Fixture->new();
    return  $fixture->dbh;

}

sub trials_list {
    my $self = shift;
    my @trials = ('Kasese solgs trial', 'trial2 NaCRRI');

    return \@trials;
}

sub accessions_list {
    my $self = shift;
    my @accessions = ('UG120001', 'UG120002', 'UG120003', 'UG120004', 'UG120005', 'UG120006', 'UG120007', 'UG120008', 'UG120009', 'UG120010', 'UG120011', 'UG120012', 'UG120013', 'UG120014', 'UG120015', 'UG120016', 'UG120017', 'UG120018', 'UG120019', 'UG120020', 'UG120021', 'UG120022', 'UG120023', 'UG120024', 'UG120025', 'UG120026', 'UG120027', 'UG120028', 'UG120029', 'UG120030', 'UG120031', 'UG120032', 'UG120033', 'UG120034' );

    return \@accessions;

}

sub plots_list {
    my $self = shift;
    my @plots_list = ('UG120001_block:1_plot:TP1_2012_NaCRRI','UG120002_block:1_plot:TP2_2012_NaCRRI','UG120003_block:1_plot:TP3_2012_NaCRRI', 'UG120004_block:1_plot:TP4_2012_NaCRRI', 'UG120005_block:1_plot:TP5_2012_NaCRRI', 'UG120006_block:1_plot:TP6_2012_NaCRRI', 'UG120007_block:1_plot:TP7_2012_NaCRRI', 'UG120008_block:1_plot:TP8_2012_NaCRRI', 'UG120009_block:1_plot:TP9_2012_NaCRRI', 'UG120010_block:1_plot:TP10_2012_NaCRRI', 'UG120011_block:1_plot:TP11_2012_NaCRRI', 'UG120012_block:1_plot:TP12_2012_NaCRRI', 'UG120013_block:1_plot:TP13_2012_NaCRRI', 'UG120014_block:1_plot:TP14_2012_NaCRRI', 'UG120015_block:1_plot:TP15_2012_NaCRRI', 'UG120016_block:1_plot:TP16_2012_NaCRRI', 'UG120017_block:1_plot:TP17_2012_NaCRRI', 'UG120018_block:1_plot:TP18_2012_NaCRRI', 'UG120019_block:1_plot:TP19_2012_NaCRRI', 'UG120020_block:1_plot:TP20_2012_NaCRRI', 'UG120021_block:1_plot:TP21_2012_NaCRRI', 'UG120022_block:1_plot:TP22_2012_NaCRRI', 'UG120023_block:2_plot:TP23_2012_NaCRRI', 'UG120024_block:2_plot:TP24_2012_NaCRRI', 'UG120025_block:2_plot:TP25_2012_NaCRRI', 'UG120026_block:2_plot:TP26_2012_NaCRRI', 'UG120027_block:2_plot:TP27_2012_NaCRRI', 'UG120028_block:2_plot:TP28_2012_NaCRRI', 'UG120029_block:2_plot:TP29_2012_NaCRRI', 'UG120030_block:2_plot:TP30_2012_NaCRRI', 'UG120031_block:2_plot:TP31_2012_NaCRRI', 'UG120032_block:2_plot:TP32_2012_NaCRRI', 'UG120033_block:2_plot:TP33_2012_NaCRRI', 'UG120034_block:2_plot:TP34_2012_NaCRRI', 'UG120035_block:2_plot:TP35_2012_NaCRRI', 'UG120036_block:2_plot:TP36_2012_NaCRRI', 'UG120037_block:2_plot:TP37_2012_NaCRRI', 'UG120038_block:2_plot:TP38_2012_NaCRRI', 'UG120039_block:2_plot:TP39_2012_NaCRRI', 'UG120040_block:2_plot:TP40_2012_NaCRRI', 'UG120041_block:2_plot:TP41_2012_NaCRRI', 'UG120042_block:2_plot:TP42_2012_NaCRRI', 'UG120043_block:2_plot:TP43_2012_NaCRRI', 'UG120044_block:2_plot:TP44_2012_NaCRRI', 'UG120045_block:3_plot:TP45_2012_NaCRRI', 'UG120046_block:3_plot:TP46_2012_NaCRRI', 'UG120047_block:3_plot:TP47_2012_NaCRRI', 'UG120048_block:3_plot:TP48_2012_NaCRRI', 'UG120049_block:3_plot:TP49_2012_NaCRRI', 'UG120050_block:3_plot:TP50_2012_NaCRRI', 'UG120051_block:3_plot:TP51_2012_NaCRRI', 'UG120052_block:3_plot:TP52_2012_NaCRRI', 'UG120053_block:3_plot:TP53_2012_NaCRRI', 'UG120054_block:3_plot:TP54_2012_NaCRRI', 'UG120055_block:3_plot:TP55_2012_NaCRRI', 'UG120056_block:3_plot:TP56_2012_NaCRRI', 'UG120057_block:3_plot:TP57_2012_NaCRRI', 'UG120058_block:3_plot:TP58_2012_NaCRRI', 'UG120059_block:3_plot:TP59_2012_NaCRRI', 'UG120060_block:3_plot:TP60_2012_NaCRRI');

    return \@plots_list;

}
###
1;
###
