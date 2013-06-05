package CXGN::TrialDesign;

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;
use Try::Tiny;
use R::YapRI::Base;
use R::YapRI::Data::Matrix;

has 'stock_list' => (isa => 'ArrayRef[Str]', is => 'rw', predicate => 'has_stock_list', clearer => 'clear_stock_list');
has 'control_list' => (isa => 'ArrayRef[Str]', is => 'rw', predicate => 'has_control_list', clearer => 'clear_control_list');
has 'number_of_blocks' => (isa => 'Int', is => 'rw', predicate => 'has_number_of_blocks', clearer => 'clear_number_of_blocks');
has 'number_of_reps' => (isa => 'Int', is => 'rw', predicate => 'has_number_of_reps', clearer => 'clear_number_of_reps');
has 'block_size' => (isa => 'Int', is => 'rw', predicate => 'has_block_size', clearer => 'clear_block_size');
has 'maximum_block_size' => (isa => 'Int', is => 'rw', predicate => 'has_maximum_block_size', clearer => 'clear_maximum_block_size');
has 'plot_name_prefix' => (isa => 'Str', is => 'rw', predicate => 'has_plot_name_prefix', clearer => 'clear_plot_name_prefix');
has 'plot_name_suffix' => (isa => 'Str', is => 'rw', predicate => 'has_plot_name_suffix', clearer => 'clear_plot_name_suffix');
has 'plot_start_number' => (isa => 'Int', is => 'rw', predicate => 'has_plot_start_number', clearer => 'clear_plot_start_number');
has 'plot_number_increment' => (isa => 'Int', is => 'rw', predicate => 'has_plot_number_increment', clearer => 'clear_plot_number_increment');


1;
