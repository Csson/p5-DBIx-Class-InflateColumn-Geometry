# NAME

DBIx::Class::InflateColumn::Geometry::MultiPolygon - Work easier with MultiPolygons

![Requires Perl 5.8.1](https://img.shields.io/badge/perl-5.8.1-brightgreen.svg) [![Travis status](https://api.travis-ci.org//.svg?branch=master)](https://travis-ci.org//)

# VERSION

Version 0.0001, released 2015-10-08.

# SYNOPSIS

    package My::Schema::Result::Country;

    use DBIx::Class::Candy -components => [qw/InflateColumn::Geometry::MultiPolygon/];
    
    # other columns

    column boundary => {
        data_type => 'multipolygon',
        geom_mp_radius => 6_371_009,
    };

# DESCRIPTION

Use this inflator to easily translate between Perl structures and MultiPolygons.

    my $schema = My::Schema->connect(...);

    # Lets say you have a multi polygon in a Perl array reference:

    my $borders = [
        [
            [
                [10, 60], [20, 60] [20, 70], [10, 70], [10, 60],
            ],
            [
                [14, 62], [16, 62] [16, 64], [14, 64], [14, 62],
                [18, 67], [19, 67] [19, 68], [18, 68], [18, 67],
            ]
        ],
        [
            [
                [5, 50], [7, 50] [7, 53], [5, 53], [5, 50],
            ],
        ]
    ];

    # Then you use it:
    $schema->Country->create({
        ...,
        boundary => $borders,
    });

    # And later...
    my $borders_from_db = $schema->resultset('Country')->search->first->boundary->polygons;

    # $borders_from_db is identical to $borders

    # Spherical area calculated on geom_mp_radius
    print $schema->resultset('Country')->search->first->boundary->area

## Configuration

**`data_type`**

`data_type` should be set to 'multipolygon'.

**`geom_mp_radius`**

`geom_mp_radius` defines the spherical radius used for the [area](https://metacpan.org/pod/area) method.

The default value is 6,371,009 meters, which is the mean Earth's [mean radius](https://en.wikipedia.org/wiki/Earth_radius#Mean_radius).

# INFLATION

When you inflate the column, you get back a [DBIx::Class::InflateColumn::Core::MultiPolygonInfo](https://metacpan.org/pod/DBIx::Class::InflateColumn::Core::MultiPolygonInfo) object.

# COMPATIBILITY

This module has (so far) been tested on MariaDB 10.1.7, and should be compatible with all Mysql versions, and Mysql derivatives, that has geospatial functionality.

The following database functions are used:

- AsText
- MultiPolygonFromText
- MultiPolygon

# HOMEPAGE

[https://metacpan.org/release/DBIx-Class-InflateColumn-MultiPolygon](https://metacpan.org/release/DBIx-Class-InflateColumn-MultiPolygon)

# AUTHOR

Erik Carlsson <info@code301.com>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Erik Carlsson <info@code301.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
