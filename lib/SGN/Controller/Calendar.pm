
package SGN::Controller::Calendar;

use Moose;

use Data::Dumper;


use CXGN::Calendar;
use CXGN::People::Roles;
use SGN::Model::Cvterm;
use URI::FromHash 'uri';

BEGIN { extends 'Catalyst::Controller'; }


1;
