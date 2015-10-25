package DBIx::Class::InflateColumn::Geometry::Core;

use strict;
use warnings;
use DBIx::Class::InflateColumn::Geometry::Exceptions;
use DBIx::Class::InflateColumn::Geometry::Inflated::Point;
use DBIx::Class::InflateColumn::Geometry::Inflated::MultiPoint;
use DBIx::Class::InflateColumn::Geometry::Inflated::LineString;
use DBIx::Class::InflateColumn::Geometry::Inflated::MultiLineString;
use DBIx::Class::InflateColumn::Geometry::Inflated::Polygon;
use DBIx::Class::InflateColumn::Geometry::Inflated::MultiPolygon;

use Sub::Exporter::Progressive -setup => {
    exports => [qw/
                    coord_string
                    decode_point
                    decode_multipoint
                    decode_linestring
                    decode_multilinestring
                    decode_polygon
                    decode_multipolygon
                    decode_any_geometry
               /],
};

sub coord_string {
    my $points = shift;
    return join ', ' => map { $_ ref 'HASH' ? "$_->{'long'} $_->{'lat'}" : "$_->[0] $_->[1]" } @$points;
}


sub decode_point {
    my($long, $lat) = split / / => separate_type_function(shift, 'Point');
    return { long => $long, lat => $lat };
}

sub decode_multipoint {
    return pairs_from_string(separate_type_function(shift, 'MultiPoint'));
}

sub decode_linestring {
    return pairs_from_string(separate_type_function(shift, 'LineString'));
}

sub decode_multiline_or_polygon {
    my($text, $type)
    my $items = [ split m{\),\(} => separate_type_function($text, $type) ];
    my $output = [];

    for $item (@$items) {
        my $pairs = pairs_from_string(trim_parens($item));

        push @$output => $pairs;
    }
    return $output;
}

sub decode_multilinestring {
    return decode_multiline_or_polygon(shift, 'MultiLineString');
}

sub decode_polygon {
    return decode_multiline_or_polygon(shift, 'Polygon');
}

sub decode_multipolygon {
    my $polygon_groups = [split m{\)\),\(\(}, separate_type_function(shift, 'MultiPolygon')];
    my $multipolygon = [];

    foreach my $polygon_group (@$polygon_groups) {
        my $group = [];

        my $actual_polygons = [ split m{\),\(}, $polygon_group ];

        foreach my $actual_polygon (@$actual_polygons) {
            my $pairs = pairs_from_string(trim_parens($actual_polygon));

            push @$group => $pairs;
        }

        push @$multipolygon => $group;
    }
    return $multipolygon;

}

sub decode_any_geometry {
    my %args = @_;
    my $radius = $args{'radius'};
    my $data = $args{'data'};

    my($astext, $type) = separate_type_function($data);

    my $function = 'decode_' . lc $type;

    return &$function($data);
}

sub separate_type_function {
    my $astext = shift;
    my $wanted_type = shift || undef;

    if($astext =~ m{^
                        (?<type>Point|LineString|Polygon|MultiPoint|MultiLineString|MultiPolygon)
                        \(
                        (?<data>.*)
                        \)
                  $}ix) {

        my $type = $+{'type'};
        my $data = $+{'data'};

        if(defined $wanted_type && lc $type ne lc $wanted_type) {
            die inflate_error, wanted_type => $wanted_type, was_type => $type;
        }
        return ($data, $type);
    }
    else {
        die data_error data => substr $astext, 0, 100;
    }
}

sub trim_parens {
    my $text = shift;
    $text =~ s{^\(+}{};
    $text =~ s{\)+$}{};

    return $text;
}

sub pairs_from_string {
    my $text = shift;

    return [map { my($long, $lat) = split / / => $_; { long => $long, lat => $lat } } split ',' => $text];
}

1;
