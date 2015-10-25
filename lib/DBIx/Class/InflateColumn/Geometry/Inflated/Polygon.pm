package DBIx::Class::InflateColumn::Geometry::Inflated::Polygon;

use strict;
use warnings;
use Moo;

# VERSION
# ABSTRACT: An inflated Polygon

with qw/
    DBIx::Class::InflateColumn::Geometry::Role::Common
    DBIx::Class::InflateColumn::Geometry::Role::Area
/;

sub area {
    my $self = shift;

    my $polygons = $self->data;
    my $total_area  = 0;

    # the first polygon is the outer ring, the rest
    # are inner rings (and therefore subtracts from the area covered by the outer ring).
    $total_area += $self->_calculate_area($polygons->[0]);

    foreach my $index (1 .. scalar @$polygons - 1) {
        my $inner_polygon = $polygons->[$index];
        $total_area -= $self->_calculate_area($inner_polygon);
    }

    return $total_area;

}

1;
