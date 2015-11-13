package DBIx::Class::InflateColumn::Geometry::Util;

use strict;
use warnings;
use DBIx::Class::InflateColumn::Geometry::Exceptions;
use DBIx::Class::InflateColumn::Geometry::Inflated::Point;
use DBIx::Class::InflateColumn::Geometry::Inflated::MultiPoint;
use DBIx::Class::InflateColumn::Geometry::Inflated::LineString;
use DBIx::Class::InflateColumn::Geometry::Inflated::MultiLineString;
use DBIx::Class::InflateColumn::Geometry::Inflated::Polygon;
use DBIx::Class::InflateColumn::Geometry::Inflated::MultiPolygon;
use Mojo::Util 'dumper';
use Try::Tiny;
use Sub::Exporter::Progressive -setup => {
    exports => [qw/
                    coord_string
                    decode_point
                    decode_multipoint
                    decode_linestring
                    decode_multilinestring
                    decode_polygon
                    decode_multipolygon
                    deflate_point
                    deflate_multipoint
                    deflate_linestring
                    deflate_multilinestring
                    deflate_polygon
                    deflate_multipolygon
                    inflate_any_geometry
                    deflate_any_geometry
                    parse_deflate_value
               /],
    groups => {
        point => [qw/decode_point deflate_point/],
        multipoint => [qw/decode_multipoint deflate_multipoint/],
        linestring => [qw/decode_linestring deflate_linestring/],
        multilinestring => [qw/decode_multilinestring deflate_multilinestring/],
        polygon => [qw/decode_polygon deflate_polygon/],
        multipolygon => [qw/decode_multipolygon deflate_multipolygon/],
    },
};

sub coord_string {
    my $points = shift;
    try {
        return join ', ' => map { ref $_ eq 'HASH' ? "$_->{'long'} $_->{'lat'}" : "$_->[0] $_->[1]" } @$points;
    }
    catch {
        warn dumper $points;
        die $_;
    };
}


sub decode_point {
    my $value = shift;

    my($data, undef) = separate_type_function($value, 'Point');
    my($long, $lat) = split / / => $data;

    return [$long + 0, $lat + 0];
}

sub decode_multipoint {
    return pairs_from_string(separate_type_function(shift, 'MultiPoint'));
}

sub decode_linestring {
    return pairs_from_string(separate_type_function(shift, 'LineString'));
}

sub decode_multiline_or_polygon {
    my($text, $type) = @_;
    my $items = [ split m{\),\(} => separate_type_function($text, $type) ];
    my $output = [];

    for my $item (@$items) {
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

sub inflate_any_geometry {
    my %args = @_;
    my $radius = $args{'radius'};
    my $data = $args{'data'};
    
    my $type;
    try {
        (undef, $type) = separate_type_function($data);
    }
    catch {
        die $_ . $_->data if $_->isa(DataError);
    };

    return lc $type eq 'point'           ? decode_point($data)
         : lc $type eq 'multipoint'      ? decode_multipoint($data)
         : lc $type eq 'linestring'      ? decode_linestring($data)
         : lc $type eq 'multilinestring' ? decode_multilinestring($data)
         : lc $type eq 'polygon'         ? decode_polygon($data)
         : lc $type eq 'multipolygon'    ? decode_multipolygon($data)
         :                                 undef
         ;

}

sub separate_type_function {
    my $astext = shift;
    my $wanted_type = shift || undef;

    if($astext =~ m{\A(?<type>POINT|LINESTRING|POLYGON|MULTIPOINT|MULTILINESTRING|MULTIPOLYGON)\((?<data>.*)\)\z}im) {

        my $type = $+{'type'};
        my $data = $+{'data'};

        if(defined $wanted_type && lc $type ne lc $wanted_type) {
            die inflate_error, wanted_type => $wanted_type, was_type => $type;
        }
        return ($data, $type);
    }
    else {
        warn substr $astext, 0, 100;
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

    return [map { my($long, $lat) = split / / => $_; [$long + 0, $lat + 0] } split ',' => $text];
}

sub parse_deflate_value {
    my $value = shift;
    my $type = undef;

    if(ref $value eq 'HASH') {
        if(exists $value->{'geometry'}) {
            $type = $value->{'geometry'}{'type'};
            $value = $value->{'geometry'}{'coordinates'};
        }
        elsif(exists $value->{'coordinates'}) {
            $value = $value->{'coordinates'};
        }
        else {
            die deflate_error;
        }
    }

    return ($value, $type);
}


sub deflate_linestring {
    my ($value, undef)  = parse_deflate_value(shift);
    my $textified = coord_string($value);

    return \qq{LineStringFromText('LINESTRING($textified)')};
}

sub deflate_multilinestring {
    my ($value, undef)  = parse_deflate_value(shift);
    my $textified = join ',' => map { '('.coord_string($_).')' } @$value;

    return \qq{MultiLineStringFromText('MULTILINESTRING($textified)')};
}

sub deflate_multipoint {
    my ($value, undef)  = parse_deflate_value(shift);
    my $textified = coord_string($value);

    return \qq{MultiPointFromText('MULTIPOINT($textified)')};
}

sub deflate_multipolygon {
    my ($value, undef)  = parse_deflate_value(shift);
    my $multipolygon = [];

    foreach my $group (@$value) {
        my $coord_strings = [ map { '('.coord_string($_).')' } @$group ];

        # The first element in this array ref is the outer ring,
        # the following are the inner rings
        push @$multipolygon => '(' . (join ",\n" => @$coord_strings) . ')';
    }
    my $textified = join ",\n" => @$multipolygon;

    return \qq{MultiPolygonFromText('MULTIPOLYGON($textified)')};
}

sub deflate_point {
    my ($value, undef)  = parse_deflate_value(shift);

    my $textified = ref $value eq 'HASH'  ? "$value->{'long'} $value->{'lat'}"
                  : ref $value eq 'ARRAY' ? "$value->[0] $value->[1]"
                  :                         $value
                  ;
    #my $textified = coord_string($value);

    return \qq{PointFromText('POINT($textified)')};
}

sub deflate_polygon {
    my ($value, undef) = parse_deflate_value(shift);
    my $textified = join ',' => map { '('.coord_string($_).')' } @$value;

    return \qq{PolygonFromText('POLYGON($textified)')};
}

sub deflate_any_geometry {
    my $val = shift;

    my($value, $type) = parse_deflate_value($val);
    $type = lc $type;

    $value = $type eq 'point'           ? deflate_point($val)
           : $type eq 'multipoint'      ? deflate_multipoint($val)
           : $type eq 'linestring'      ? deflate_linestring($val)
           : $type eq 'multilinestring' ? deflate_multilinestring($val)
           : $type eq 'polygon'         ? deflate_polygon($value)
           : $type eq 'multipolygon'    ? deflate_multipolygon($val)
           :                              undef
           ;

    die deflate_error if !defined $value;
    return $value;
}

1;
