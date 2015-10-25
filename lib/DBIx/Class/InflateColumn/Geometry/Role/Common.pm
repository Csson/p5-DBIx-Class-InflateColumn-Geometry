package DBIx::Class::InflateColumn::Geometry::Role::Common;

use strict;
use warnings;
use Moo::Role;

has data => (
    is => 'rw',
);
has radius => (
    is => 'ro',
    default => 6_371_009,
);
has lat_dist => (
    is => 'ro',
    default => sub { return 4 * atan2(1, 1) * shift->radius / 180; }, # pi * radius / 180
    lazy => 1,
);

1;
