package DBIx::Class::InflateColumn::Geometry::Inflated::MultiPolygon;

use strict;
use warnings;
use Moo;

# VERSION
# ABSTRACT: An inflated MultiPolygon

with qw/
    DBIx::Class::InflateColumn::Geometry::Role::Common
    DBIx::Class::InflateColumn::Geometry::Role::Area
/;

sub area {
    my $self = shift;

    my $multi = $self->data;
    my $total_area  = 0;

    foreach my $polygons (@$multi) {

        # the first polygon in a group is the outer ring, the rest
        # are inner rings (and therefore subtracts from the area covered by the outer ring).
        $total_area += $self->_calculate_area($polygons->[0]);

        foreach my $index (1 .. scalar @$polygons - 1) {
            my $inner_polygon = $polygons->[$index];
            $total_area -= $self->_calculate_area($inner_polygon);
        }
    }

    return $total_area;

}

1;

=pod

=head1 SYNOPSIS

See L<DBIx::Class::InflateColumn::Geometry::MultiPolygon> for configuration information.

    my $polygons = $country->boundary->polygons;

    my $area = $country->boundary->area;

=head1 DESCRIPTION

An instance of this class represents the inflated value of a C<multipolygon> column for a result instance.

=head1 METHODS

=head2 polygons()

This method returns the MultiPolygon translated to its original Perl data structure: An array ref of array refs of array refs of coordinates.

=head2 area()

This method returns the spherical area of the MultiPolygon, calculated from the value of L<geometry_radius|DBIx::Class::InflateColumn::Geometry::MultiPolygon/geometry_radius>. The method itself is unit agnostic, and
its answer depends on the value of C<geometry_radius>: If you set the radius in kilometres, the area is given in square kilometers, and so on. It doesn't know
about units at all, so it is equally useful for calculating polygons on footballs as on the Sun.

It currently uses the sinusoidal projection to calculate the area. It is a simple formula, but the downside is that big polygons (or rather big distances between points
on the polygons) introduces errors in the calculations. On Earth, unless you have several degrees between points, the error should generally be 0-0.5%.

Pull requests with more precise formulas are welcome.