package DBIx::Class::InflateColumn::MultiPolygon::Info;

use strict;
use warnings;
use Moo;
use Math::Trig qw/deg2rad/;

# VERSION
# ABSTRACT

has multi => (
    is => 'ro',
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

sub area {
    my $self = shift;

    my $multi = $self->multi;
    my $total_area  = 0;

    foreach my $polygons (@$multi) {

        # the first polygon in a group is the outer ring, the rest
        # are inner rings (and therefore subtracts from the area covered by the outer ring).
        $total_area += $self->calculate_area($polygons->[0]);

        foreach my $index (1 .. scalar @$polygons) {
            my $inner_polygon = $polygons->[$index];
            $total_area -= $self->calculate_area($inner_polygon);
        }
    }

    return $total_area;

}

sub calculate_area {
    my $self = shift;
    my $pairs = shift;

    $pairs = [ map { {
                        lat => $_->{'lat'} * $self->lat_dist,
                        long => $_->{'long'} * $self->lat_dist * cos(deg2rad($_->{'lat'}))
                    } } @$pairs ];

    my $area = 0;
    my $max_index = scalar @$pairs - 2;

    foreach my $index (-1 .. $max_index) {
        $area += $pairs->[$index]{'long'} * ($pairs->[$index - 1]{'lat'} - $pairs->[$index + 1]{'lat'});
    }
    return abs($area) / 2;
}

1;
