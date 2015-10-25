package DBIx::Class::InflateColumn::Geometry::Role::Area;

use strict;
use warnings;
use Moo::Role;
use Math::Trig qw/deg2rad/;

requires 'area';

sub _calculate_area {
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
