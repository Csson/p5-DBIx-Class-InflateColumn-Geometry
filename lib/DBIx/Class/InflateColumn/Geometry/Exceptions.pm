package DBIx::Class::InflateColumn::Geometry::Exceptions;

use strict;
use warnings;
use Throwable::SugarFactory;

exception DataError => "Data doesn't match geometry pattern" => has => [data => (is => 'ro')];
exception InflateError => "Error inflating" => has => [wanted_type => (is => 'ro')], has => [was_type => (is => 'ro')];

1;
